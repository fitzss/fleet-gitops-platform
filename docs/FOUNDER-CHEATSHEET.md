# Founder Demo - Quick Reference

## Start Demo
```bash
make founder-demo
```

## Key URLs
- **ArgoCD UI**: https://localhost:8080  
- **Site A API**: http://localhost:8001/fleet  
- **GitHub Repo**: [github.com/fitzss/fleet-gitops-platform](https://github.com/fitzss/fleet-gitops-platform)  

---

## Demo Commands (in order)

### 1. Show multi-site
Just point at ArgoCD UI

### 2. Scale Site A
```bash
make founder-scale
```

### 3. Self-healing
```bash
kubectl scale deploy robot-0 -n fleet-site-a --replicas=5
# Wait 10 seconds - it auto-corrects
```

### 4. Fleet telemetry
```bash
make founder-status
```

### 5. Rollback
```bash
git revert HEAD --no-edit && git push
```

---

## Key Messages
- "Git push = deployed everywhere"  
- "No manual operations"  
- "Automatic error correction"  
- "Vendor independent"  
- "Scales to hundreds of sites"  

---

## If Things Go Wrong
```bash
make demo-reset  # Fixes everything
```
