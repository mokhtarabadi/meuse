# Meuse Registry Deployment Issues & Lessons Learned

**Date:** September 9, 2025  
**Deployment Target:** cargo.surfshield.org  
**Final Status:** ⚠️ **PARTIAL SUCCESS** - Registry stores crates but cannot serve them as dependencies

## 🎯 Summary

We successfully deployed a Meuse registry that can:

- ✅ Accept crate uploads via `cargo publish`
- ✅ Store crates in database and filesystem
- ✅ Authenticate users and manage API tokens
- ✅ Provide search functionality via API

**CRITICAL FAILURE:** The registry **cannot serve crates as dependencies** because the Git index integration is broken.

---

## 🚨 Critical Issues Discovered

### 1. **Git Index Integration Completely Broken**

**Issue:** While crates upload successfully to the registry database, the Git index (required for Cargo dependency
resolution) is never updated.

**Impact:**

- `cargo search` works (uses API)
- `cargo publish` works (stores in database)
- **Using crates as dependencies FAILS** - Cargo can't find them

**Root Causes:**

- JGit container permission issues
- Missing/incorrect Git authentication setup
- GitHub token not working with JGit configuration

**Evidence:**

```bash
# This works (API search):
cargo search surfshield-test-crate --registry surfshield
# Returns: surfshield-test-crate = "0.1.0"

# This fails (dependency resolution):
# Cargo.toml: surfshield-test-crate = { version = "0.1.0", registry = "surfshield" }
# Error: no matching package named `surfshield-test-crate` found
```

### 2. **JGit Container Permissions**

**Issue:** JGit cannot create necessary directories inside the Meuse container.

**Logs:**

```
Creating XDG_CONFIG_HOME directory /home/meuse/.config failed
Cannot save config file 'FileBasedConfig[/home/meuse/.jgitconfig]'
java.nio.file.AccessDeniedException: /home/meuse
```

**Impact:** JGit authentication and Git operations fail silently.

### 3. **File System Permissions for Crate Storage**

**Issue:** Meuse container cannot create subdirectories for crate storage.

**Logs:**

```
java.io.FileNotFoundException: /app/crates/test-jgit-crate/0.1.0/download (No such file or directory)
```

**Impact:** Some crate publishes fail with 500 Internal Server Error.

---

## 🔧 Issues We Successfully Fixed

### 1. **Password Hash Generation Bug** ✅ **FIXED**

**Original Issue:** Password generation happened AFTER config file creation, resulting in empty passwords in
config.yaml.

**Solution:** Moved password generation to before config creation in install.sh:

```bash
# Line 331: Generate passwords BEFORE config creation
POSTGRES_PASS=$(openssl rand -base64 32)

# Line 335: Then create config with actual password
cat > config/config.yaml << EOF
database:
  password: !secret "${POSTGRES_PASS}"
```

### 2. **Password Hash Extraction Bug** ✅ **FIXED**

**Original Issue:** Bash special characters (`$`) in password hash patterns caused grep to fail.

**Solution:** Proper escaping in install.sh line 595:

```bash
PASSWORD_HASH=$(echo "$HASH_OUTPUT" | grep '\$2a\$' | tail -1)
```

### 3. **Debug and Logging Improvements** ✅ **FIXED**

**Added:** Comprehensive debug logging and retry mechanisms:

- Debug output for password hash extraction
- 3-attempt retry logic for critical operations
- 10-retry health checking with proper wait times
- Graceful fallback with manual recovery instructions

---

## 🧪 Testing Results

### ✅ **Working Functionality:**

- **Authentication:** Admin user creation, API token generation
- **Database Operations:** Crate metadata storage in PostgreSQL
- **API Endpoints:** Health check, crate listing, search functionality
- **HTTPS Access:** Secure access via Cloudflare (cargo.surfshield.org)
- **Docker Services:** All containers start and run healthy

### ❌ **Broken Functionality:**

- **Dependency Resolution:** Cannot use published crates as dependencies
- **Git Index Updates:** No metadata pushed to GitHub fork
- **Complete Cargo Workflow:** Only API operations work, not standard usage

### 🔬 **Test Evidence:**

**Successful API Test:**

```bash
curl -H "Authorization: TOKEN" https://cargo.surfshield.org/api/v1/meuse/crate
# Returns: {"crates": [{"name": "surfshield-test-crate", "version": "0.1.0"}]}
```

**Failed Dependency Test:**

```bash
# Cargo.toml: surfshield-test-crate = { version = "0.1.0", registry = "surfshield" }
cargo build
# Error: no matching package named `surfshield-test-crate` found
```

**GitHub Index Verification:**

- Repository: https://github.com/mokhtarabadi/crates.io-index
- Status: **No new commits** - our crate metadata never pushed
- Commits: Still at original 4,053 commits from upstream

---

## 📋 Outstanding Issues to Resolve

### **Priority 1: Fix Git Index Integration**

**Options:**

1. **Fix JGit Container Permissions**
    - Create proper home directory for meuse user
    - Set correct file permissions in Docker setup
    - Ensure JGit can write to Git repository

2. **Switch to Shell Git Method**
    - Use `type: "shell"` instead of `type: "jgit"`
    - Configure Git authentication in container
    - Set up proper SSH keys or HTTPS authentication

3. **Implement Option 3: Self-Hosted Git**
    - Use fully private Git repository on same server
    - Serve Git repository via nginx git-http-backend
    - Eliminate external dependencies completely

### **Priority 2: Verify Complete Workflow**

Must test end-to-end:

1. ✅ Publish crate with `cargo publish --registry surfshield`
2. ❌ **FIX:** Use crate as dependency in another project
3. ❌ **FIX:** Verify `cargo build` downloads and compiles successfully

### **Priority 3: Production Hardening**

- Container security improvements
- Proper backup and recovery procedures
- Monitoring and alerting setup
- Performance optimization for large crate repositories

---

## 💡 Key Learnings

### **Architecture Understanding:**

- **Meuse has two data flows:** Database storage (works) + Git index updates (broken)
- **Cargo requires Git index:** API-only registries don't support dependencies
- **Container permissions matter:** JGit needs proper filesystem access

### **Deployment Insights:**

- **Test the complete workflow:** Don't assume API success means full functionality
- **Debug logging is essential:** Our password debugging saved hours of troubleshooting
- **Incremental testing works:** Each component should be verified separately

### **Registry Ecosystem:**

- **Option 2 (GitHub fork) requires working Git integration** - not just configuration
- **Option 3 (self-hosted) is more complex but provides true privacy**
- **Container networking and permissions are critical for Git operations**

---

## 🎯 Recommended Next Steps

### **For Complete Registry Functionality:**

1. **Immediate Fix:** Implement proper JGit container permissions
2. **Alternative:** Switch to shell Git with proper authentication
3. **Long-term:** Implement self-hosted Git HTTP backend for full privacy

### **For Production Deployment:**

1. **Fix the Git integration** (any of the three options above)
2. **Test complete dependency workflow** before declaring success
3. **Implement proper monitoring** and backup procedures
4. **Security hardening** for production use

---

## 🔚 Current Status

**Registry State:**

- **Deployed:** ✅ Running at cargo.surfshield.org
- **Functional:** ⚠️ 60% - Can store crates but cannot serve them as dependencies
- **Production Ready:** ❌ Critical functionality missing

**Server State:**

- **Cleaned:** ✅ All Docker containers and volumes removed
- **Git Auth:** ✅ All Git configuration cleaned from root user
- **Ready:** ✅ Clean slate for next deployment attempt

**Next Deployment:** Must focus on Git index integration as Priority #1.

---

*This document captures all issues discovered during our September 8-9, 2025 deployment attempt and provides a roadmap
for achieving a fully functional private Rust registry.*