# 🚀 Meuse Registry Quick Start (5-Minute Setup)

Deploy your private Rust crate registry behind Cloudflare SSL in just 5 minutes!

## ⚡ Prerequisites

- Server with Docker installed
- Domain name (can be subdomain like `registry.yoursite.com`)
- Cloudflare account (free tier works)

## 🎯 One-Command Setup

```bash
# Download and run the automated installer
curl -sSL https://raw.githubusercontent.com/mcorbin/meuse/master/install.sh | bash
```

**Don't trust random curl commands?** Follow the manual steps below! 👇

## 📝 Manual Setup (Step by Step)

### 1. Download Files

```bash
# Create project directory
mkdir meuse-registry && cd meuse-registry

# Download all required files
curl -O https://raw.githubusercontent.com/mcorbin/meuse/master/docker-compose.yml
curl -O https://raw.githubusercontent.com/mcorbin/meuse/master/nginx.conf  
curl -O https://raw.githubusercontent.com/mcorbin/meuse/master/.env.example
mkdir config && curl -o config/config.yaml https://raw.githubusercontent.com/mcorbin/meuse/master/config/config.yaml
```

### 2. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Generate secure passwords (Linux/Mac)
sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(openssl rand -base64 32)/" .env
sed -i "s/MEUSE_FRONTEND_SECRET=.*/MEUSE_FRONTEND_SECRET=$(openssl rand -hex 32)/" .env  
sed -i "s/DOMAIN=.*/DOMAIN=registry.yourdomain.com/" .env

# Edit with your domain
nano .env  # Change DOMAIN=registry.yourdomain.com
```

### 3. Setup Git Index

```bash
# Fork https://github.com/rust-lang/crates.io-index on GitHub first!

# Clone YOUR fork (replace YOUR_USERNAME)
git clone https://github.com/YOUR_USERNAME/crates.io-index.git temp-index
cd temp-index

# Configure the index for your domain
cat > config.json << EOF
{
    "dl": "https://registry.yourdomain.com/api/v1/crates",
    "api": "https://registry.yourdomain.com",
    "allowed-registries": ["https://github.com/rust-lang/crates.io-index"]
}
EOF

# Commit and push
git add config.json
git commit -m "Configure for Meuse registry"
git push origin master

cd ..
```

### 4. Update Meuse Config

```bash
# Edit config/config.yaml and update YOUR_USERNAME
sed -i 's/YOUR_USERNAME/your-actual-github-username/' config/config.yaml
```

### 5. Deploy Services

```bash
# Start everything
docker compose up -d

# Wait for services to be ready (30-60 seconds)
sleep 45

# Check status
docker compose ps
```

### 6. Create Admin User

```bash
# Generate password hash
PASSWORD_HASH=$(docker compose exec meuse java -jar /app/meuse.jar password your_admin_password | grep '$2a$' | tail -1)

# Create admin user
docker compose exec postgres psql -U meuse -d meuse -c "INSERT INTO users(id, name, password, description, active, role_id) VALUES ('f3e6888e-97f9-11e9-ae4e-ef296f05cd17', 'admin', '$PASSWORD_HASH', 'Administrator user', true, '867428a0-69ba-11e9-a674-9f6c32022150');"

# Create API token  
TOKEN=$(curl -s --header "Content-Type: application/json" --request POST --data '{"name":"admin_token","validity":365,"user":"admin","password":"your_admin_password"}' http://localhost/api/v1/meuse/token | jq -r '.token')

echo "🎉 Your API token: $TOKEN"
echo "Save this token - you'll need it for Cargo!"
```

## ☁️ Cloudflare SSL Setup

### 1. Add Domain to Cloudflare

1. Go to Cloudflare dashboard → Add site
2. Add your domain (e.g., `yourdomain.com`)
3. Update nameservers at your registrar

### 2. DNS Configuration

```
Type: A
Name: registry (or your subdomain)  
Content: YOUR_SERVER_IP
Proxy status: Proxied (orange cloud)
```

### 3. SSL Settings

```
SSL/TLS → Overview → Full (not Full strict)
SSL/TLS → Edge Certificates → Always Use HTTPS: ON
```

### 4. Test Your Registry

```bash
# Should show "Meuse is running."
curl https://registry.yourdomain.com/healthz
```

## 🦀 Configure Cargo

### Add Registry

```bash
# Add to ~/.cargo/config.toml
mkdir -p ~/.cargo
cat >> ~/.cargo/config.toml << EOF
[registries.myregistry]
index = "https://github.com/YOUR_USERNAME/crates.io-index"

# Optional: Use as default registry
[source.crates-io]
replace-with = "myregistry"

[source.myregistry]  
registry = "https://github.com/YOUR_USERNAME/crates.io-index"
EOF
```

### Add Authentication

```bash
# Add to ~/.cargo/credentials.toml (use your actual token)
cat >> ~/.cargo/credentials.toml << EOF
[registries.myregistry]
token = "YOUR_API_TOKEN_FROM_STEP_6"
EOF
```

## 🎉 Test Your Registry!

```bash
# Create test crate
cargo new test-crate --lib
cd test-crate

# Add some metadata to Cargo.toml
cat >> Cargo.toml << EOF
description = "Test crate for my registry"
license = "MIT"
EOF

# Publish to your registry
cargo publish --registry myregistry

# Search for it
cargo search test-crate --registry myregistry
```

## 🔧 Quick Commands

```bash
# Check status
docker compose ps

# View logs  
docker compose logs -f meuse

# Restart services
docker compose restart

# Stop everything
docker compose down

# List crates via API
curl -H "Authorization: YOUR_TOKEN" https://registry.yourdomain.com/api/v1/meuse/crate
```

## 🆘 Troubleshooting

**Services not starting?**

```bash
docker compose logs meuse
```

**Can't publish crates?**

```bash
# Check git index is accessible
docker compose exec meuse ls -la /app/index
```

**SSL not working?**

- Wait 10-15 minutes for Cloudflare SSL certificates
- Ensure DNS is proxied (orange cloud)
- Check SSL mode is "Full" not "Full (strict)"

**Need help?**

- Check full documentation: `DOCKER_SETUP.md`
- Open issue: https://github.com/mcorbin/meuse/issues

---

**🎊 Congratulations!** You now have a production-ready private Rust registry with SSL!

**Total setup time:** ~5 minutes (plus DNS propagation)