# Multi-Service Node.js E-commerce on AWS with Terraform + Docker

## 1. Overview

Four Node.js backend services (user, product, cart, order) and a React frontend are
containerized with Docker, pushed to Docker Hub, and deployed to a single AWS EC2
instance that is provisioned entirely by Terraform. A user-data script installs Docker,
pulls the images and starts every container. The frontend is reachable on the instance's
public IP / DNS (port 80).

## 2. Architecture

```
                      Internet
                         |
                  (HTTP :80 only)
                         |
        +----------------v-----------------+  AWS VPC 10.0.0.0/16
        |  Public subnet 10.0.1.0/24       |  (Internet Gateway + route table)
        |  EC2 Ubuntu 22.04 (t3.small)     |
        |  +----------------------------+  |
        |  | Docker network: ecommerce-net |
        |  |                            |  |
        |  |  frontend (nginx) :80  ----+--+--> /api/auth,/api/users   -> user-service    :3001
        |  |                            |  |    /api/products,/categories -> product-service :3002
        |  |                            |  |    /api/cart              -> cart-service    :3003
        |  |                            |  |    /api/orders,/payments  -> order-service   :3004
        |  |  mongo :27017 (internal)   |  |
        |  +----------------------------+  |
        +----------------------------------+
```

| Container        | Image                                   | Port | Notes                                   |
|------------------|-----------------------------------------|------|-----------------------------------------|
| frontend         | `<user>/ecommerce-frontend:v1`          | 80   | React build served by nginx, proxies `/api/*` |
| user-service     | `<user>/ecommerce-user-service:v1`      | 3001 | Auth + profile                          |
| product-service  | `<user>/ecommerce-product-service:v1`   | 3002 | Catalog                                 |
| cart-service     | `<user>/ecommerce-cart-service:v1`      | 3003 | Calls product-service                   |
| order-service    | `<user>/ecommerce-order-service:v1`     | 3004 | Calls cart/product/user services        |
| mongo            | `mongo:6.0` (official)                  | 27017 | Database used by the 4 services (not published) |

**Design decisions**

- **nginx reverse proxy in the frontend image.** React bakes API URLs in at build time, but the
  public IP is unknown until Terraform runs. The frontend is built with relative URLs (`/`)
  and nginx forwards `/api/*` to the right container by Docker DNS name. No IP is hard-coded,
  and only port 80 is exposed to the internet.
- **MongoDB as a sixth container.** The existing services connect to MongoDB; running it on the
  same Docker network keeps the app fully functional. It is not published outside the host.
- **Backends start with `node server.js`**, because the repo's `npm start` uses nodemon
  (a dev dependency that is not installed in production images).
- **Small app changes:** each service got a `/` route returning `<name> Service Running`
  (assignment requirement) and a `.catch` on `mongoose.connect` so a slow database start
  does not crash the process.

## 3. Repository layout

```
backend/<service>/Dockerfile      # one per backend service
frontend/Dockerfile, nginx.conf   # multi-stage build -> nginx
docker-compose.yml                # local test of the whole stack
scripts/build_and_push.sh         # build, tag, push 5 images
terraform/
  main.tf                         # VPC, subnet, IGW, routes, SG, EC2
  variables.tf  outputs.tf
  user_data.sh.tpl                # installs Docker, pulls + runs containers
  terraform.tfvars.example
```

## 4. Step-by-step

### Prerequisites
Docker, Terraform >= 1.3, AWS CLI configured (`aws configure`), a Docker Hub account.

### Step 1 - Build and test images locally
```bash
docker compose up --build          # http://localhost:8080
curl localhost:3001/               # user Service Running
curl localhost:3002/               # product Service Running
curl localhost:3003/               # cart Service Running
curl localhost:3004/               # order Service Running
curl localhost:8080/live           # Frontend is Live
docker compose down
```

### Step 2 - Tag and push to Docker Hub
```bash
export DOCKERHUB_USER=<your-username>
./scripts/build_and_push.sh v1
```
Then, on hub.docker.com, make sure all 5 repositories are **Public** (new repos usually are on
the free plan).

### Step 3 - Provision and deploy with Terraform
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # set dockerhub_username
terraform init
terraform plan
terraform apply
```
`terraform apply` prints the outputs (public IP, DNS, application URL, status URLs).
Allow about 3-5 minutes after apply for user-data to finish installing Docker and pulling images.

### Step 4 - Verify
```bash
IP=$(terraform output -raw public_ip)
curl http://$IP/live               # Frontend is Live
curl http://$IP/status/user        # user Service Running
curl http://$IP/status/product     # product Service Running
curl http://$IP/status/cart        # cart Service Running
curl http://$IP/status/order       # order Service Running
curl http://$IP/api/products       # real API call through nginx -> product-service
```
Open `http://<public_ip>` in a browser for the React storefront.

If a key pair was configured: `ssh -i key.pem ubuntu@$IP`, then
`docker ps`, `docker logs <container>`, and `sudo cat /var/log/user-data.log`.

### Step 5 - Clean up
```bash
terraform destroy
```

## 5. Security group rules

| Direction | Port      | Source             | Purpose                                   |
|-----------|-----------|--------------------|-------------------------------------------|
| Inbound   | 80/tcp    | 0.0.0.0/0          | Public HTTP to the frontend               |
| Inbound   | 3001-3004 | the SG itself      | Internal service-to-service traffic       |
| Inbound   | 22/tcp    | `var.ssh_cidr`     | SSH (restrict to your IP in real use)     |
| Outbound  | all       | 0.0.0.0/0          | apt and Docker Hub access                 |

Backend ports are **not** open to the internet; they are reachable publicly only through the
nginx proxy on port 80.

## 6. Mapping to the evaluation criteria

| Criterion                                         | Where it is met |
|---------------------------------------------------|-----------------|
| VPC, subnet and security group setup (10)         | `main.tf`: `aws_vpc`, `aws_subnet.public`, IGW, route table, `aws_security_group.app` |
| EC2 provisioning with Docker setup (10)           | `aws_instance.app` (Ubuntu 22.04 AMI); user-data step 1 installs Docker |
| Container deployment via user-data (10)           | `user_data.sh.tpl` steps 2-4: pull 5 images from Docker Hub and run on ports 80, 3001-3004 |
| Public access to frontend (10)                    | Port 80 open, `map_public_ip_on_launch`, `/live` and the React homepage, Terraform outputs the IP/DNS/URL |
| Documentation (10)                                | This file |

## 7. Troubleshooting

| Symptom | Check |
|---------|-------|
| Site not reachable right after apply | user-data is still running; wait a few minutes, then `sudo tail -f /var/log/user-data.log` |
| `docker pull` fails in the log | Image repo is private or `dockerhub_username` / `image_tag` is wrong |
| nginx container exits immediately | A backend container is missing (`docker ps -a`); fix it and `docker restart frontend` |
| Changed images and want to redeploy | Push a new tag, update `image_tag`, run `terraform apply` (instance is replaced) |
| Product list is empty | The database is new and has no products; the services are working |
