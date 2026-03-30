# GitHub Repository Setup - Task 18

This guide provides step-by-step instructions to push your local Packer + Terraform project to GitHub.

## Prerequisites

Before starting, ensure:
- You have a GitHub account
- You have git configured with your GitHub credentials
- All 17 previous tasks are complete and committed locally
- Your local branch is ahead of origin with 15 commits ready to push

## Step 1: Create GitHub Repository (Manual)

1. Go to [github.com](https://github.com) and log in
2. Click the **+** icon in the top right corner, select **New repository**
3. Configure the repository:
   - **Repository name**: `devops-spring26-packer-terraform`
   - **Description**: `Infrastructure as Code with Packer and Terraform for AWS`
   - **Visibility**: Choose **Public** or **Private** (your preference)
   - **Initialize repository**: Do NOT check any boxes (we have local commits to push)
   - Click **Create repository**

4. After creation, you'll see the repository URL in the form:
   - HTTPS: `https://github.com/jsrahoi-dev/devops-spring26-packer-terraform.git`
   - SSH: `git@github.com:jsrahoi-dev/devops-spring26-packer-terraform.git`

**Note down your repository URL** - you'll need it in the next steps.

---

## Step 2: Add GitHub Remote (Command Line)

Open your terminal and navigate to the project directory:

```bash
cd /Users/unotest/dev/grad_school/devops/devops-spring26-packer-terraform
```

Add the GitHub repository as a remote (use HTTPS or SSH based on your preference):

### Option A: Using HTTPS (recommended if you use GitHub tokens)
```bash
git remote add origin https://github.com/jsrahoi-dev/devops-spring26-packer-terraform.git
```

### Option B: Using SSH (if you have SSH keys configured)
```bash
git remote add origin git@github.com:jsrahoi-dev/devops-spring26-packer-terraform.git
```

---

## Step 3: Verify Remote Configuration

Verify that the remote was added correctly:

```bash
git remote -v
```

You should see output like:
```
origin  https://github.com/jsrahoi-dev/devops-spring26-packer-terraform.git (fetch)
origin  https://github.com/jsrahoi-dev/devops-spring26-packer-terraform.git (push)
```

---

## Step 4: Push to GitHub

Push your local commits to the GitHub repository:

```bash
git push -u origin main
```

**What this does:**
- `-u` sets the upstream tracking (future pushes only need `git push`)
- `origin` is the remote name you just added
- `main` is the branch name

**Expected output:**
```
Enumerating objects: 60, done.
Counting objects: 100% (60/60), done.
Delta compression using up to 8 threads
Compressing objects: 100% (40/40), done.
Writing objects: 100% (60/60), ...
...
To https://github.com/jsrahoi-dev/devops-spring26-packer-terraform.git
 * [new branch]      main -> main
Branch 'main' set up to track remote tracking branch 'main' from 'origin'.
```

---

## Step 5: Verify Repository on GitHub

1. Go to your GitHub repository: `https://github.com/jsrahoi-dev/devops-spring26-packer-terraform`
2. Verify you see:
   - All 15 commits in the commit history
   - The following folders and files:
     - `packer/` directory with Packer configurations
     - `terraform/` directory with Terraform configurations
     - `docs/` directory with documentation
     - `README.md` with project overview
     - `.gitignore` file
   - Check the commit history by clicking the "X commits" link to see all commits

3. Click on individual commits to verify they contain:
   - Packer templates and variables
   - Terraform configurations (main.tf, variables.tf, outputs.tf, etc.)
   - Security group and VPC configurations
   - Proper git author (jsrahoi-dev)

---

## Step 6: Update README (Optional)

If you want to add the GitHub repository URL to your README:

1. Open `README.md` in your editor
2. Add a section near the top with the repository link:

```markdown
## Repository

- **GitHub**: https://github.com/jsrahoi-dev/devops-spring26-packer-terraform
```

3. Commit and push the change:
```bash
git add README.md
git commit -m "docs: add GitHub repository URL"
git push
```

---

## Troubleshooting

### Authentication Failed
- **HTTPS**: Ensure your GitHub personal access token is correct. Use `git config --global credential.helper osxkeychain` on macOS.
- **SSH**: Verify your SSH key is added to GitHub (Settings > SSH and GPG keys). Test with `ssh -T git@github.com`.

### Remote Already Exists
If you get an error that "origin" already exists:
```bash
git remote remove origin
git remote add origin [YOUR_GITHUB_URL]
```

### Push Rejected
If the push is rejected:
- Ensure the GitHub repository is truly empty (no README, license, etc.)
- If it's not empty, pull first: `git pull origin main`
- Then push: `git push origin main`

### Wrong Branch Name
If your local branch is not "main":
```bash
git branch -M main  # Rename current branch to 'main'
git push -u origin main
```

---

## Verification Checklist

After completing all steps, verify:

- [ ] GitHub repository created at `https://github.com/jsrahoi-dev/devops-spring26-packer-terraform`
- [ ] Remote added: `git remote -v` shows origin URL
- [ ] All 15 commits pushed: GitHub shows full commit history
- [ ] All folders and files visible on GitHub:
  - [ ] packer/
  - [ ] terraform/
  - [ ] docs/
  - [ ] README.md
  - [ ] .gitignore
- [ ] Local branch tracking set: `git status` shows "Your branch is up to date with 'origin/main'"
- [ ] Git author is jsrahoi-dev on pushed commits

---

## Success Indicators

Your Task 18 is complete when:

1. ✓ GitHub repository is created and accessible
2. ✓ All local commits are pushed to GitHub
3. ✓ Repository URL is documented
4. ✓ All infrastructure-as-code files are visible on GitHub
5. ✓ Git history is preserved and visible

---

## Next Steps

With your repository on GitHub, you can now:
- Share the repository link with team members
- Enable collaboration on the infrastructure code
- Set up CI/CD pipelines
- Implement branch protection rules
- Archive the repository for version control

---

## Quick Reference Commands

```bash
# Navigate to project
cd /Users/unotest/dev/grad_school/devops/devops-spring26-packer-terraform

# Add remote (use your actual GitHub URL)
git remote add origin https://github.com/jsrahoi-dev/devops-spring26-packer-terraform.git

# Verify remote
git remote -v

# Push to GitHub
git push -u origin main

# Check status
git status

# View commit history
git log --oneline -10
```

---

**Created**: 2026-03-29
**Task**: Task 18 - Push to GitHub Repository
**Status**: Ready for execution
