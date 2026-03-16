# Ansible Explained - Understanding Configuration Management in the Rewards Web Tier

**Document Purpose:** Deep dive educational guide explaining Ansible, its role in this architecture, and detailed breakdown of every configuration decision.

**Target Audience:** Developers and operations engineers learning infrastructure automation

**Last Updated:** March 2026

---

## Table of Contents

1. [What is Ansible? (Fundamentals)](#1-what-is-ansible-fundamentals)
2. [Terraform vs Ansible - Why Both?](#2-terraform-vs-ansible---why-both)
3. [Why Ansible in This Architecture?](#3-why-ansible-in-this-architecture)
4. [Our Ansible Architecture - Component Breakdown](#4-our-ansible-architecture---component-breakdown)
5. [Step-by-Step Configuration Breakdown](#5-step-by-step-configuration-breakdown)
6. [Idempotency in Practice](#6-idempotency-in-practice)
7. [Workflow: How It All Works Together](#7-workflow-how-it-all-works-together)
8. [Production Benefits](#8-production-benefits)
9. [Key Takeaways](#9-key-takeaways)

---

## 1. What is Ansible? (Fundamentals)

### Definition

**Ansible** is an open-source automation tool for configuration management, application deployment, and orchestration. It allows you to define the desired state of your servers, and Ansible ensures they match that state.

### Key Characteristics

#### Agentless Architecture

Unlike other configuration management tools (Puppet, Chef, SaltStack), Ansible doesn't require agents installed on target machines.

**How it works:**
- Ansible control node connects directly to managed nodes via SSH or AWS Systems Manager (SSM)
- No daemon processes running on target servers
- No agent upgrades or maintenance required
- Minimal footprint on managed systems

**Benefits:**
- ✅ Lower operational overhead (no agent management)
- ✅ Faster initial setup (no agent installation)
- ✅ Better security posture (fewer running processes)
- ✅ Works with ephemeral infrastructure (containers, auto-scaling)

#### Declarative vs Imperative

**Declarative (What Ansible Does):**
```yaml
# You declare: "I want this package installed"
- name: Ensure Python 3 is installed
  yum:
    name: python3
    state: present
```
- You specify **what** you want (Python 3 installed)
- Ansible figures out **how** to achieve it
- Ansible checks current state first, only acts if needed

**Imperative (Traditional Scripts):**
```bash
# You specify exact commands: "Do these steps"
yum install python3 -y
systemctl enable my-service
systemctl start my-service
```
- You specify **how** to do something
- Runs commands regardless of current state
- Can cause errors if already done

#### Idempotency

**Definition:** Running the same playbook multiple times produces the same result without unintended side effects.

**Example:**

Running this playbook 10 times:
```yaml
- name: Create user account
  user:
    name: appuser
    state: present
```

**Result:** 
- Run 1: Creates user → **changed**
- Runs 2-10: User already exists → **ok** (no change)
- System state: Identical after each run

**Why this matters:**
- Safe to run repeatedly (automation, scheduled jobs)
- Self-healing (drift correction)
- Predictable outcomes

#### Push-Based Model

**Ansible (Push):**
```
Control Node → pushes config → Managed Nodes
```
- You trigger deployments from control node
- Immediate execution
- Know exactly when changes happen

**Alternative: Pull-Based (Puppet, Chef):**
```
Managed Nodes ← pull config ← Config Server
```
- Nodes periodically fetch configuration
- Delayed execution (polling interval)
- Less control over timing

**Why push for this project:**
- Deploy on-demand (CI/CD trigger)
- Immediate verification
- Better for dev environments (controlled deployments)

---

## 2. Terraform vs Ansible - Why Both?

### Clear Comparison Table

| Aspect | Terraform | Ansible |
|--------|-----------|---------|
| **Purpose** | Infrastructure provisioning | Configuration management & application deployment |
| **What it manages** | Cloud resources (VPC, EC2, ALB, RDS, S3) | OS configuration, packages, services, applications, files |
| **State Management** | Tracks infrastructure state in `.tfstate` file | Stateless (checks current state each run) |
| **Language** | HCL (HashiCorp Configuration Language) | YAML playbooks |
| **Lifecycle** | Create → Update → Destroy | Configure → Update → Reconfigure |
| **Resource Tracking** | Knows what it created, can destroy it | No tracking, focuses on desired state |
| **Best At** | Infrastructure as Code | Configuration as Code |
| **Example Use** | "Create an EC2 instance with these specs" | "Install Python, deploy app, start service" |
| **When to use** | **Build the server** | **Configure what's on the server** |

### Real-World Analogy

Think of building and setting up a house:

#### Terraform = Building Contractor
- **Role:** Constructs the physical house
- **Responsibilities:**
  - Lays foundation (VPC, networking)
  - Builds walls (EC2 instances)
  - Installs plumbing (security groups, routing)
  - Connects electricity (IAM roles, policies)
- **Deliverable:** Empty but functional house (bare OS)

#### Ansible = Interior Designer
- **Role:** Furnishes and configures the house
- **Responsibilities:**
  - Installs furniture (application software)
  - Hangs pictures (configuration files)
  - Sets up utilities (systemd services)
  - Arranges everything (permissions, file structure)
- **Deliverable:** Fully configured, move-in ready house

### Why You Need Both

**Terraform alone:**
- ✅ Creates EC2 instance
- ❌ Instance has no application
- ❌ No security hardening
- ❌ Manual configuration required

**Ansible alone:**
- ❌ Can't create cloud resources
- ✅ Can configure existing servers
- ❌ Needs infrastructure to exist first

**Terraform + Ansible together:**
- ✅ Complete automation (infrastructure + configuration)
- ✅ Clear separation of concerns
- ✅ Each tool does what it's best at
- ✅ Repeatable, auditable, version controlled

---

## 3. Why Ansible in This Architecture?

### Specific Reasons for This Project

#### 1. Separation of Concerns

**Clear Boundaries:**

```
┌─────────────────────────────────────────────────┐
│ Terraform's Responsibility                      │
│                                                  │
│ • Create VPC (10.0.0.0/16)                      │
│ • Create subnets in us-east-1a and us-east-1b  │
│ • Create security groups                        │
│ • Create ALB and target group                   │
│ • Launch EC2 instances (bare Amazon Linux)      │
│ • Configure IAM roles and policies              │
└─────────────────────────────────────────────────┘
                      ↓ Hands off to
┌─────────────────────────────────────────────────┐
│ Ansible's Responsibility                        │
│                                                  │
│ • Update system packages                        │
│ • Install Python, dependencies                  │
│ • Configure system security (SSH hardening)     │
│ • Deploy health-service application             │
│ • Create systemd service                        │
│ • Configure logging and log rotation            │
└─────────────────────────────────────────────────┘
```

**Benefits:**
- Infrastructure team manages Terraform
- Application team can update Ansible roles
- Changes don't require full infrastructure redeployment
- Faster iteration cycles

#### 2. Instance Replaceability (Auto Scaling)

**Scenario:** Auto Scaling Group terminates unhealthy instance and launches replacement

**Without Ansible:**
```
1. Auto Scaling launches new EC2 instance
2. Instance boots with bare Amazon Linux
3. ❌ No application installed
4. ❌ Health checks fail
5. ❌ Instance never receives traffic
6. ❌ Manual intervention required
```

**With Ansible:**
```
1. Auto Scaling launches new EC2 instance
2. Instance boots, user-data adds Ansible tags
3. ✅ CI/CD detects new instance (via tags)
4. ✅ Ansible auto-discovers instance
5. ✅ Ansible configures (installs app, starts service)
6. ✅ Health checks pass
7. ✅ Instance joins ALB target group
8. ✅ Receives production traffic
9. ✅ Zero manual intervention
```

**Production Impact:**
- Self-healing infrastructure
- True auto-scaling (new instances automatically configured)
- Reduced mean time to recovery (MTTR)

#### 3. Configuration Drift Management

**Configuration Drift:** When servers diverge from their intended state due to manual changes.

**Example Scenario:**
```
Day 1: All servers identical
Day 15: Engineer manually edits /etc/ssh/sshd_config on one server
Day 30: Different server has different Python version
Day 60: Snowflake servers (each unique)
```

**How Ansible Fixes This:**
```yaml
# Run playbook on all servers
ansible-playbook -i inventory/aws_ec2.yml playbook.yml

# Ansible checks each server
Server 1: SSH config matches → ok (no change)
Server 2: SSH config wrong → changed (fixed)
Server 3: Python 3.9 installed → ok
Server 4: Python 3.8 installed → changed (upgraded to 3.9)

Result: All servers back to identical state
```

**Benefits:**
- Run periodically (weekly/monthly) to correct drift
- Idempotent = safe to run anytime
- Audit trail of changes in Git

#### 4. Application Lifecycle Independence

**Traditional Approach (Everything in Terraform):**
```
Update application code
  ↓
Update Terraform user-data script
  ↓
Run terraform apply
  ↓
Terraform destroys ALL instances
  ↓
Terraform creates NEW instances
  ↓
5-10 minute downtime
  ↓
Service restored
```

**Our Approach (Ansible for Application):**
```
Update application code
  ↓
Update Ansible role
  ↓
Run ansible-playbook
  ↓
Ansible updates application on running instances
  ↓
Rolling restart (2-3 seconds downtime per instance)
  ↓
Service never fully down
```

**Impact:**
- Application updates: seconds (Ansible) vs minutes (Terraform)
- No infrastructure recreation
- Reduced deployment risk

#### 5. Team Collaboration

**Clear Ownership:**

| Team | Tool | Responsibilities |
|------|------|------------------|
| **Infrastructure/Platform Team** | Terraform | VPC design, networking, security groups, IAM, ALB configuration |
| **Application/Development Team** | Ansible | Application deployment, service configuration, monitoring setup |

**Benefits:**
- Developers don't need deep AWS knowledge
- Infrastructure team doesn't need to know application internals
- Each team works in their domain
- Pull requests reviewed by appropriate experts

---

## 4. Our Ansible Architecture - Component Breakdown

### 4.1 Connection Method: SSM Session Manager

#### What We're Using

In our [`ansible.cfg`](../ansible/ansible.cfg):
```ini
[defaults]
# Note: Will be configured for SSM in Phase 3
# connection = aws_ssm
remote_user = ec2-user
```

In production, this would use the AWS SSM connection plugin instead of traditional SSH.

#### Why SSM Instead of SSH?

**Traditional SSH Approach:**
```
Developer → SSH Key → Port 22 → EC2 Instance

Issues:
❌ SSH keys to manage, rotate, and secure
❌ Port 22 must be open (security risk)
❌ Need bastion host ($15-30/month)
❌ Or need VPN (complexity, cost)
❌ Lost keys = locked out
❌ No audit trail of who did what
```

**SSM Approach:**
```
Developer → AWS IAM → SSM API → Secure Tunnel → EC2 Instance

Benefits:
✅ No SSH keys to manage
✅ No port 22 exposure (zero open ports)
✅ No bastion host needed (cost savings)
✅ No VPN required
✅ IAM-based authentication (MFA supported)
✅ Complete audit trail in CloudTrail
✅ Session recording available
✅ Fine-grained access control
```

#### How SSM Connection Works

**Step-by-step:**

1. **Ansible initiates connection:**
   ```bash
   ansible-playbook playbook.yml
   ```

2. **Ansible uses aws_ssm plugin:**
   - Makes API call to AWS SSM service
   - Authenticates using IAM credentials (from local AWS CLI config)

3. **SSM creates secure tunnel:**
   - SSM agent on EC2 instance establishes TLS connection to SSM service
   - No inbound ports required (outbound HTTPS only)

4. **Commands execute:**
   - Ansible sends commands through tunnel
   - SSM agent executes as `ec2-user`
   - Output returns through tunnel

5. **Audit logging:**
   - CloudTrail records session start/end
   - Optionally record full session (commands + output)

**Security Benefits:**

```
Traditional SSH:
┌──────────┐     SSH Key     ┌──────────┐
│ Engineer │──────:22────────│ Instance │
└──────────┘                 └──────────┘
           ↑
      Attack Surface: Port 22 exposed

SSM:
┌──────────┐   IAM Auth    ┌──────────┐   TLS    ┌──────────┐
│ Engineer │───────────────│ SSM API  │──────────│ Instance │
└──────────┘               └──────────┘          └──────────┘
                                ↓
                          CloudTrail Logs
           ↑
      Attack Surface: Zero open ports
```

#### Cost Savings

**With Bastion Host:**
- Bastion: t4g.nano (24/7) = ~$30/month
- Elastic IP = $3.60/month
- **Total: ~$34/month**

**With SSM:**
- SSM Standard (includes our usage) = **$0/month**
- **Total: $0**

**Annual savings: ~$408**

### 4.2 Dynamic Inventory: Automatic Server Discovery

#### What We're Using

Our dynamic inventory [`inventory/aws_ec2.yml`](../ansible/inventory/aws_ec2.yml):

```yaml
---
plugin: aws_ec2
regions:
  - us-east-1
filters:
  tag:Environment: dev
  tag:Service: rewards
  instance-state-name: running
keyed_groups:
  - key: tags.Environment
    prefix: env
  - key: tags.Service
    prefix: service
hostnames:
  - instance-id
compose:
  ansible_host: instance_id
```

#### Why Dynamic Inventory?

**Traditional Static Inventory (Bad for Cloud):**

`inventory/hosts.ini`:
```ini
[rewards-servers]
10.0.2.45 ansible_user=ec2-user
10.0.2.67 ansible_user=ec2-user
10.0.2.89 ansible_user=ec2-user
```

**Problems:**
❌ IP addresses change when instances restart
❌ Auto Scaling creates new instances → not in inventory
❌ Manual updates required after every infrastructure change
❌ Stale inventory (deleted instances still listed)
❌ Human error (typos in IP addresses)
❌ Doesn't scale

**Dynamic Inventory (Good for Cloud):**

**Benefits:**
✅ Queries AWS API in real-time
✅ Always up-to-date (no manual updates)
✅ Auto-discovers new instances
✅ Ignores terminated instances
✅ Uses tags for intelligent grouping
✅ Works seamlessly with Auto Scaling

#### How It Works

**Step 1: Ansible runs playbook**
```bash
ansible-playbook -i inventory/aws_ec2.yml playbook.yml
```

**Step 2: Dynamic inventory plugin queries AWS**
```
AWS API Call: ec2:DescribeInstances

Filters:
- tag:Environment = dev
- tag:Service = rewards
- instance-state-name = running

Returns:
- i-0a1b2c3d4e5f6g7h8 (10.0.2.45) - running
- i-1b2c3d4e5f6g7h8i9 (10.0.2.67) - running
- i-2c3d4e5f6g7h8i9j0 (10.0.2.89) - running
```

**Step 3: Inventory groups created automatically**
```
[env_dev]           # All instances tagged Environment=dev
i-0a1b2c3d4e5f6g7h8
i-1b2c3d4e5f6g7h8i9
i-2c3d4e5f6g7h8i9j0

[service_rewards]   # All instances tagged Service=rewards
i-0a1b2c3d4e5f6g7h8
i-1b2c3d4e5f6g7h8i9
i-2c3d4e5f6g7h8i9j0
```

**Step 4: Ansible applies configuration**
```
Connecting to i-0a1b2c3d4e5f6g7h8...
Connecting to i-1b2c3d4e5f6g7h8i9...
Connecting to i-2c3d4e5f6g7h8i9j0...
```

#### Auto Scaling Scenario

**Scenario:** Auto Scaling launches a new instance

**Timeline:**
```
T+0:00 - Auto Scaling launches i-3d4e5f6g7h8i9j0k1
T+0:30 - Instance boots, user-data runs
T+0:45 - User-data applies tags (Environment=dev, Service=rewards)
T+1:00 - CI/CD triggers Ansible (or scheduled run)
T+1:05 - Dynamic inventory discovers new instance
T+1:10 - Ansible configures new instance
T+2:00 - Instance healthy, joins ALB
T+2:10 - Receives production traffic
```

**No manual intervention required!**

#### Tag Strategy

Our tagging strategy ensures proper discovery:

```hcl
# In Terraform: terraform/modules/compute/main.tf
tags = {
  Name           = "dev-rewards-instance"
  Environment    = "dev"
  Service        = "rewards"
  AnsibleManaged = "true"
  ManagedBy      = "terraform"
}
```

**Tag Purposes:**
- `Environment=dev`: Group by environment (dev/staging/prod)
- `Service=rewards`: Group by service (rewards/users/payments)
- `AnsibleManaged=true`: Marks instances that should be configured
- `ManagedBy=terraform`: Audit trail (who created this)

### 4.3 Role Structure: Organized Configuration

#### What Are Ansible Roles?

**Definition:** Roles are reusable, self-contained units of automation with a standardized directory structure.

**Why use roles?**
- Modular design (separation of concerns)
- Reusable across projects
- Easier to test
- Clear organization
- Industry standard

#### Standard Role Directory Structure

```
roles/
└── role-name/
    ├── tasks/          # What to do (main logic)
    │   └── main.yml
    ├── handlers/       # Actions triggered by changes
    │   └── main.yml
    ├── templates/      # Configuration file templates (Jinja2)
    │   └── config.j2
    ├── files/          # Static files to copy
    │   └── script.sh
    ├── vars/           # Variables (high precedence)
    │   └── main.yml
    ├── defaults/       # Default variables (low precedence)
    │   └── main.yml
    ├── meta/           # Role metadata and dependencies
    │   └── main.yml
    └── README.md       # Documentation
```

#### Our Three Roles

**Role Organization:**
```
ansible/roles/
├── common/             # Security baseline (all instances)
│   ├── tasks/
│   │   └── main.yml    # Package updates, security hardening
│   ├── templates/
│   │   └── logrotate.conf.j2
│   └── handlers/
│       └── main.yml    # Service restarts
│
├── health-service/     # Application deployment
│   ├── tasks/
│   │   └── main.yml    # Deploy app, configure service
│   ├── templates/
│   │   ├── health-service.py.j2
│   │   ├── rewards-health.service.j2
│   │   └── fetch-secrets.sh.j2
│   └── handlers/
│       └── main.yml    # Service restart handler
│
└── observability/      # Monitoring and logging
    └── tasks/
        └── main.yml    # CloudWatch agent, log config
```

#### Role Execution Order

In [`playbook.yml`](../ansible/playbook.yml):

```yaml
- hosts: tag_Service_rewards
  roles:
    - common              # 1. Apply security baseline first
    - health-service      # 2. Deploy application
    - observability       # 3. Configure monitoring last
```

**Why this order?**

1. **Common first:** Establishes security baseline before anything else
2. **Health-service second:** Needs common packages (Python) installed first
3. **Observability last:** Monitors the application (must exist first)

---

## 5. Step-by-Step Configuration Breakdown

### COMMON ROLE: Security Baseline

**Purpose:** Establish a secure, consistent baseline configuration on all instances.

#### Task 1: System Package Updates

```yaml
- name: Update all packages to latest versions
  yum:
    name: '*'
    state: latest
    update_cache: yes
```

**What it does:**
- Updates all installed packages to latest available versions
- Equivalent to: `yum update -y`

**Why we do this:**
- **Security patches:** Critical vulnerabilities fixed
- **Bug fixes:** Stability improvements
- **Compliance:** Many standards require updated packages
- **Baseline consistency:** All instances start from same package versions

**When it runs:**
- Every playbook execution
- Only updates if new versions available (idempotent)

**Production impact:**
- **Without updates:** Vulnerable to known exploits
- **With updates:** Protected against CVEs (Common Vulnerabilities and Exposures)

**Example output:**
```
TASK [common : Update all packages] ****
changed: [i-0a1b2c3d] => (15 packages updated: openssl, curl, systemd, ...)
```

#### Task 2: Install Required Packages

```yaml
- name: Install essential system packages
  yum:
    name:
      - chrony          # Time synchronization
      - logrotate       # Log management
      - python3         # Application runtime
      - python3-pip     # Python package manager
      - aws-cli         # AWS command line tools
    state: present
```

**What it does:**
- Ensures specific packages are installed
- Equivalent to: `yum install -y chrony logrotate python3 ...`

**Why each package:**

1. **`chrony`** - Time synchronization daemon
   - **Purpose:** Keep system clock accurate
   - **Why critical:**
     - AWS API signatures have 15-minute time tolerance
     - Certificate validation requires correct time
     - Log timestamps must be accurate for debugging
     - CloudWatch metrics need accurate timestamps
   - **Without chrony:** After ~24 hours, clock drift can cause API failures

2. **`logrotate`** - Log rotation utility
   - **Purpose:** Automatically rotate, compress, and delete old logs
   - **Why critical:**
     - Prevents disk from filling with logs (crashed application)
     - Manages log retention (keep last 7 days)
     - Compresses old logs (saves 80-90% disk space)
   - **Without logrotate:** Disk fills → application crashes

3. **`python3`** - Python interpreter
   - **Purpose:** Runtime for our health-service application
   - **Why this version:** Python 3.9+ (modern, maintained)

4. **`python3-pip`** - Python package manager
   - **Purpose:** Install Python libraries if needed
   - **Currently:** Not needed (health-service uses standard library only)
   - **Future-proofing:** If we add dependencies later

5. **`aws-cli`** - AWS Command Line Interface
   - **Purpose:** Fetch secrets from SSM Parameter Store
   - **Used by:** `fetch-secrets.sh` script
   - **Critical for:** Loading `APP_SECRET` at service startup

**Idempotency:**
```
Run 1: Packages not installed → installs → changed
Run 2: Packages already installed → skips → ok
Run 3: Packages already installed → skips → ok
```

#### Task 3: Configure Time Synchronization

```yaml
- name: Ensure chrony service is enabled and running
  systemd:
    name: chronyd
    enabled: yes    # Start on boot
    state: started  # Ensure running now
```

**What it does:**
- Enables `chronyd` service (starts automatically on boot)
- Starts service if not already running
- Equivalent to:
  ```bash
  systemctl enable chronyd
  systemctl start chronyd
  ```

**Why time synchronization is critical:**

1. **AWS API Authentication:**
   ```
   API Request includes timestamp: 2026-03-16T14:30:00Z
   AWS checks: |request_time - server_time| < 15 minutes
   
   If time is wrong:
   → "SignatureDoesNotMatch" error
   → API calls fail
   → Can't fetch secrets from SSM
   → Application fails to start
   ```

2. **SSL/TLS Certificate Validation:**
   ```
   Certificate valid: 2025-01-01 to 2026-12-31
   System time: 2024-12-15 (wrong!)
   
   Result: Certificate validation fails
   → HTTPS connections fail
   → Can't connect to AWS APIs
   ```

3. **Log Correlation:**
   ```
   Server 1 logs: [14:30:45] Request received
   Server 2 logs: [14:28:12] Response sent
   
   Problem: Server 2 responded BEFORE Server 1 received request?
   
   Cause: Time drift (Server 2 clock is 3 minutes slow)
   Impact: Impossible to debug issues
   ```

**Production story:**

Without chrony:
```
Day 1: Instance launches, time correct
Day 7: Clock drifts +10 minutes (slow)
Day 14: Clock drifts +20 minutes
        → AWS API calls start failing intermittently
        → Application can't fetch secrets
        → Health checks fail
        → Instance removed from ALB
        → Manual investigation required
```

With chrony:
```
Day 1: Instance launches, chrony starts
Day 7: Clock stays accurate (synced every ~64 seconds)
Day 14: Clock stays accurate
        → Everything works reliably
        → No manual intervention
```

#### Task 4: SSH Hardening

```yaml
- name: Disable SSH password authentication
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^#?PasswordAuthentication'
    line: 'PasswordAuthentication no'
    state: present
  notify: restart sshd
```

**What it does:**
- Edits `/etc/ssh/sshd_config`
- Sets `PasswordAuthentication no`
- Triggers `restart sshd` handler (only if file changed)

**Why disable password authentication:**

**Attack scenario without this:**
```
Attacker discovers port 22 open
  ↓
Attacker tries common passwords:
  admin/admin
  ec2-user/password123
  root/toor
  ...
  ↓
Brute force attack (1000s of attempts)
  ↓
Eventually guesses password
  ↓
Attacker has server access
```

**With password authentication disabled:**
```
Attacker discovers port 22 open
  ↓
Attacker tries passwords
  ↓
SSH rejects: "Password authentication disabled"
  ↓
Only SSH keys work
  ↓
Attacker needs private key (extremely difficult to obtain)
  ↓
Attack fails
```

**Defense in depth:**
- Even though we use SSM (no SSH needed)
- SSH is still enabled (emergency access)
- Harden it anyway (security layers)

**Additional SSH hardening (future):**
```yaml
- name: Advanced SSH hardening
  lineinfile:
    path: /etc/ssh/sshd_config
    line: "{{ item }}"
  loop:
    - "PermitRootLogin no"              # Can't login as root
    - "PubkeyAuthentication yes"        # Require SSH keys
    - "PasswordAuthentication no"       # No passwords
    - "ChallengeResponseAuthentication no"
    - "UsePAM no"
    - "MaxAuthTries 3"                  # Lock after 3 failures
  notify: restart sshd
```

**Handler: restart sshd**

```yaml
# handlers/main.yml
- name: restart sshd
  systemd:
    name: sshd
    state: restarted
```

**What handlers do:**
- Only run when "notified" by a task
- Only run once (even if notified multiple times)
- Run at end of play (after all tasks)

**Example:**
```
Task 1: Edit sshd_config → changed → notify restart sshd
Task 2: Edit sshd_config → changed → notify restart sshd
Task 3: Edit sshd_config → ok (no change) → (no notification)

End of play:
Handler: restart sshd (runs once)
```

**Why handlers:**
- Avoid unnecessary restarts (only restart if config changed)
- Batch restarts (multiple config changes = one restart)
- Cleaner code (separation of actions from triggers)

#### Task 5: Logrotate Configuration

```yaml
- name: Configure log rotation for application
  template:
    src: logrotate.conf.j2
    dest: /etc/logrotate.d/rewards
    owner: root
    group: root
    mode: '0644'
```

**What it does:**
- Creates configuration file from template
- Tells logrotate how to handle application logs

**Template: `logrotate.conf.j2`**

```jinja2
/var/log/rewards/*.log {
    daily                    # Rotate daily
    missingok                # Don't error if log file missing
    rotate 7                 # Keep 7 days of logs
    compress                 # Compress old logs (gzip)
    delaycompress            # Don't compress most recent rotation
    notifempty               # Don't rotate empty files
    create 0640 ec2-user ec2-user  # New log file permissions
    sharedscripts            # Run postrotate once (not per file)
    postrotate
        # Reload application to use new log file
        /bin/systemctl reload rewards-health.service > /dev/null 2>&1 || true
    endscript
}
```

**Why each directive:**

1. **`daily`**: Rotate every day at midnight
   - Alternative: `weekly`, `monthly`
   - Daily = manageable file sizes

2. **`rotate 7`**: Keep 7 days of logs
   - `health-service.log` (current)
   - `health-service.log.1.gz` (yesterday)
   - `health-service.log.2.gz` (2 days ago)
   - ...
   - `health-service.log.7.gz` (7 days ago)
   - Older logs automatically deleted

3. **`compress`**: Use gzip compression
   - 1 MB log → 100 KB compressed (~90% reduction)
   - Saves disk space
   - Old logs rarely accessed (compression OK)

4. **`delaycompress`**: Don't compress yesterday's log
   - Most recent log often still accessed
   - Faster to read uncompressed
   - Compressed the next day

5. **`notifempty`**: Don't rotate empty files
   - If application didn't log anything
   - Don't create empty rotated files

6. **`postrotate`**: Action after rotation
   - Reload application service
   - Application starts writing to new log file
   - Prevents writing to old (rotated) file

**Without logrotate:**
```
Day 1: health-service.log = 10 MB
Day 7: health-service.log = 70 MB
Day 30: health-service.log = 300 MB
Day 60: health-service.log = 600 MB
Day 90: Disk full (100% usage)
        → Application can't write logs
        → Application crashes (no space)
        → Manual cleanup required
```

**With logrotate:**
```
Day 1: health-service.log = 10 MB
Day 2: health-service.log = 10 MB
       health-service.log.1.gz = 1 MB (compressed)
Day 7: health-service.log = 10 MB
       health-service.log.1.gz to .7.gz = 7 MB total
Day 90: health-service.log = 10 MB
        health-service.log.1.gz to .7.gz = 7 MB total
        Disk usage stable: ~17 MB
```

---

### HEALTH-SERVICE ROLE: Application Deployment

**Purpose:** Deploy and configure the rewards health-service Python application.

#### Task 1: Create Application Directory

```yaml
- name: Create application directory
  file:
    path: /opt/rewards
    state: directory
    owner: root
    group: ec2-user
    mode: '0755'
```

**What it does:**
- Creates `/opt/rewards` directory if it doesn't exist
- Sets ownership: `root:ec2-user`
- Sets permissions: `755` (rwxr-xr-x)

**Why `/opt/rewards`:**
- `/opt` = Linux standard for "optional/third-party software"
- Not system files (`/usr`, `/etc`)
- Not user files (`/home`)
- Separated from system for clarity

**Why `root:ec2-user` ownership:**
- **Owner (root):** Only root can modify files
  - Prevents application from modifying its own code
  - Security: Compromised app can't change its code
- **Group (ec2-user):** Application runs as ec2-user
  - Can read files (need code to run)
  - Can't write files (can't modify)

**Why `755` permissions:**
```
7 (owner/root):    rwx (read, write, execute)
5 (group/ec2-user): r-x (read, execute)
5 (others):        r-x (read, execute)
```
- Root: Full control
- ec2-user: Read code, execute scripts
- Others: Read only (principle of least privilege)

**Security principle:**
- Application should not be able to modify its own code
- Prevents malware from persisting
- Compromised app can't install backdoors

#### Task 2: Deploy Secret Fetch Script

```yaml
- name: Deploy script to fetch secrets from SSM Parameter Store
  template:
    src: fetch-secrets.sh.j2
    dest: /opt/rewards/fetch-secrets.sh
    owner: root
    group: ec2-user
    mode: '0750'
```

**What it does:**
- Deploys script that fetches `APP_SECRET` from AWS SSM Parameter Store
- Permissions: `750` = root/ec2-user can execute, others cannot

**Template: `fetch-secrets.sh.j2`**

```bash
#!/bin/bash
set -e  # Exit on any error

# Configuration
REGION="{{ ansible_ec2_placement_region | default('us-east-1') }}"
PARAMETER_NAME="/rewards/app-secret"
ENV_FILE="/opt/rewards/.env"

# Fetch secret from SSM Parameter Store
echo "Fetching secrets from SSM Parameter Store..."
SECRET_VALUE=$(aws ssm get-parameter \
    --name "$PARAMETER_NAME" \
    --with-decryption \
    --query 'Parameter.Value' \
    --output text \
    --region "$REGION")

# Check if secret was retrieved
if [ -z "$SECRET_VALUE" ]; then
    echo "ERROR: Failed to retrieve secret from SSM"
    exit 1
fi

# Write to .env file
cat > "$ENV_FILE" << EOF
APP_SECRET=$SECRET_VALUE
AWS_REGION=$REGION
GIT_COMMIT={{ git_commit | default('unknown') }}
ENVIRONMENT={{ environment | default('dev') }}
EOF

# Secure the .env file
chmod 600 "$ENV_FILE"
chown ec2-user:ec2-user "$ENV_FILE"

echo "Secrets loaded successfully"
```

**Why we need this script:**

**Bad approach: Hard-code secrets**
```python
# DON'T DO THIS!
APP_SECRET = "super-secret-password-123"
```
- ❌ Secret in source code
- ❌ Secret in Git history (forever)
- ❌ Anyone with code access has secret
- ❌ Can't rotate secret without code deploy
- ❌ Security compliance failure

**Bad approach: Environment variable in user-data**
```bash
# DON'T DO THIS!
export APP_SECRET="super-secret-password-123"
```
- ❌ Secret visible in EC2 console (user-data)
- ❌ Secret visible in Terraform state
- ❌ Secret in process list (`ps aux`)

**Our approach: Fetch at runtime**
```bash
# GOOD!
SECRET=$(aws ssm get-parameter --name /rewards/app-secret --with-decryption)
```
- ✅ Secret never in code
- ✅ Secret never in Git
- ✅ Secret stored encrypted in AWS
- ✅ Fetched fresh at service start
- ✅ Can rotate in AWS → restart service → new secret loaded
- ✅ IAM controls who can read secret

**How it works:**

**Step 1: Store secret in AWS**
```bash
aws ssm put-parameter \
    --name /rewards/app-secret \
    --value "actual-secret-value-here" \
    --type SecureString \
    --key-id alias/aws/ssm
```
- Stored encrypted using AWS KMS
- Only accessible with IAM permissions

**Step 2: Script fetches secret**
```bash
aws ssm get-parameter \
    --name /rewards/app-secret \
    --with-decryption \          # Decrypt using KMS
    --query 'Parameter.Value' \  # Extract just the value
    --output text                # Plain text (not JSON)
```

**Step 3: Write to .env file**
```bash
cat > /opt/rewards/.env << EOF
APP_SECRET=actual-secret-value-here
AWS_REGION=us-east-1
GIT_COMMIT=abc123def
EOF

chmod 600 /opt/rewards/.env  # Only owner (ec2-user) can read
```

**Step 4: Application reads .env**
```python
import os
APP_SECRET = os.environ.get('APP_SECRET')
```

**Why `.env` file with `600` permissions:**
- Not visible in process list (`ps aux` doesn't show it)
- Not passed on command line (command line args visible)
- Only application user can read it
- Fresh on every service start
- Automatically cleaned on service stop

**Security layers:**
```
1. Secret encrypted in AWS SSM (KMS)
2. IAM role controls access (instance must have permission)
3. Fetched over HTTPS (TLS encryption)
4. Written to .env with 600 permissions (only ec2-user can read)
5. Loaded into environment variables (not in code)
6. Never logged (not in application logs or CloudWatch)
```

#### Task 3: Deploy Python Health Service

```yaml
- name: Deploy health-service application
  template:
    src: health-service.py.j2
    dest: /opt/rewards/health-service.py
    owner: root
    group: ec2-user
    mode: '0644'
```

**What it does:**
- Deploys Python application code
- Permissions: `644` = owner can write, everyone can read

**Template: `health-service.py.j2`**

```python
#!/usr/bin/env python3
"""
Rewards Health Service
Lightweight HTTP server for ALB health checks
"""
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

# Configuration from environment
PORT = int(os.environ.get('PORT', 8080))
APP_SECRET = os.environ.get('APP_SECRET', '')
AWS_REGION = os.environ.get('AWS_REGION', 'unknown')
GIT_COMMIT = os.environ.get('GIT_COMMIT', 'unknown')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')

class HealthHandler(BaseHTTPRequestHandler):
    """Handle HTTP requests"""
    
    def log_message(self, format, *args):
        """Log requests to stdout (captured by systemd)"""
        print(f"[{self.log_date_time_string()}] {format % args}")
    
    def do_GET(self):
        """Handle GET requests"""
        
        if self.path == '/health':
            # Health check endpoint
            status = "ok" if APP_SECRET else "degraded"
            
            health_data = {
                "service": "rewards",
                "status": status,
                "commit": GIT_COMMIT,
                "region": AWS_REGION,
                "environment": ENVIRONMENT
            }
            
            self.send_json_response(200, health_data)
        
        else:
            # 404 for any other path
            error_data = {
                "error": "Not Found",
                "path": self.path
            }
            self.send_json_response(404, error_data)
    
    def send_json_response(self, status_code, data):
        """Send JSON response"""
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data, indent=2).encode())

def main():
    """Start HTTP server"""
    server_address = ('', PORT)
    httpd = HTTPServer(server_address, HealthHandler)
    print(f"Starting server on port {PORT}...")
    print(f"Environment: {ENVIRONMENT}")
    print(f"Region: {AWS_REGION}")
    print(f"Commit: {GIT_COMMIT}")
    httpd.serve_forever()

if __name__ == '__main__':
    main()
```

**Why this design:**

**Lightweight:**
- No framework (Flask, Django) required
- Uses Python standard library only
- No `pip install` dependencies
- Fast startup (< 1 second)
- Low memory footprint (~10 MB)

**Health Check Response:**
```json
{
  "service": "rewards",
  "status": "ok",
  "commit": "abc123def456",
  "region": "us-east-1",
  "environment": "dev"
}
```

**Why each field:**

1. **`service`: "rewards"**
   - Identifies which service responded
   - Useful in multi-service environments
   - ALB target group can verify correct service

2. **`status`: "ok" or "degraded"**
   - "ok": APP_SECRET loaded (fully functional)
   - "degraded": APP_SECRET missing (can't function properly)
   - ALB considers "ok" healthy, "degraded" unhealthy

3. **`commit`: "abc123def456"**
   - Git SHA from CI/CD
   - Traceability: which version is deployed?
   - Debugging: "Was the fix in this version?"
   - Verification: "Did the deployment actually update?"

4. **`region`: "us-east-1"**
   - Confirms running in correct region
   - Multi-region deployments: identify which region responded
   - Debugging: "Is this the right region?"

5. **`environment`: "dev"**
   - Confirms correct environment
   - Prevents accidental cross-environment issues
   - Clear identification in logs and monitoring

**ALB Integration:**

ALB health check configuration:
```hcl
health_check {
  path                = "/health"
  port                = 8080
  protocol            = "HTTP"
  healthy_threshold   = 2      # 2 consecutive successes = healthy
  unhealthy_threshold = 3      # 3 consecutive failures = unhealthy
  timeout             = 5      # 5 seconds to respond
  interval            = 30     # Check every 30 seconds
  matcher             = "200"  # HTTP 200 = healthy
}
```

**Health check flow:**
```
Every 30 seconds:
ALB → GET http://instance:8080/health
Instance → {"service":"rewards","status":"ok",...}
ALB checks:
  ✓ HTTP 200 response
  ✓ Response within 5 seconds
  ✓ (optional) Parse JSON, check status field
Result: Instance healthy → receives traffic
```

#### Task 4: Deploy Systemd Unit File

```yaml
- name: Deploy systemd service unit
  template:
    src: rewards-health.service.j2
    dest: /etc/systemd/system/rewards-health.service
    owner: root
    group: root
    mode: '0644'
  notify:
    - daemon-reload
    - restart rewards-health
```

**What it does:**
- Creates systemd unit file
- Tells Linux how to manage the service
- Triggers daemon-reload (reload systemd)
- Triggers service restart (only if file changed)

**Template: `rewards-health.service.j2`**

```ini
[Unit]
Description=Rewards Health Service
Documentation=https://github.com/yourorg/rewards-web-tier
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ec2-user
Group=ec2-user
WorkingDirectory=/opt/rewards

# Fetch secrets BEFORE starting (runs as root via sudo)
ExecStartPre=/bin/bash /opt/rewards/fetch-secrets.sh

# Load environment variables from .env file
EnvironmentFile=/opt/rewards/.env

# Start the application
ExecStart=/usr/bin/python3 /opt/rewards/health-service.py

# Restart policy
Restart=always
RestartSec=10

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/rewards

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=rewards-health

[Install]
WantedBy=multi-user.target
```

**Section-by-section breakdown:**

**[Unit] Section - Service Metadata**

```ini
Description=Rewards Health Service
```
- Human-readable description
- Shows in `systemctl status rewards-health`

```ini
After=network-online.target
Wants=network-online.target
```
- **`After`**: Don't start until network is online
- **`Wants`**: Wait for internet connectivity
- **Why:** Application needs AWS API access (fetch secrets)
- **Without this:** Service starts before network → AWS API calls fail → service crashes

**[Service] Section - How to Run**

```ini
Type=simple
```
- Process runs in foreground (doesn't daemonize)
- Systemd monitors the main process
- If process exits → systemd knows immediately

```ini
User=ec2-user
Group=ec2-user
```
- Run as non-root user
- Security: Compromised app can't modify system
- Principle of least privilege

```ini
WorkingDirectory=/opt/rewards
```
- Current directory when running
- Relative paths resolved from here

```ini
ExecStartPre=/bin/bash /opt/rewards/fetch-secrets.sh
```
- **`ExecStartPre`**: Run BEFORE main service starts
- Fetches secrets from SSM
- Creates `/opt/rewards/.env` file
- **If this fails:** Service doesn't start (no secrets = can't run)

**Why fetch secrets in `ExecStartPre`:**
- Secrets fetched fresh on every start
- Service startup blocks until secrets loaded
- If secret fetch fails → service doesn't start (fail-safe)

```ini
EnvironmentFile=/opt/rewards/.env
```
- Load environment variables from file
- Variables available to `ExecStart` process
- Equivalent to:
  ```bash
  source /opt/rewards/.env
  python3 /opt/rewards/health-service.py
  ```

**Security benefit:**
- Environment variables not visible in `systemctl show`
- Not passed on command line (not in `ps aux`)
- Only readable by ec2-user (600 permissions)

```ini
ExecStart=/usr/bin/python3 /opt/rewards/health-service.py
```
- Main command to run
- Full path to Python (required by systemd)
- Application starts, runs indefinitely

```ini
Restart=always
RestartSec=10
```
- **`Restart=always`**: Restart on any exit (success or failure)
- **`RestartSec=10`**: Wait 10 seconds between restarts

**Why this matters:**

**Scenario 1: Application crash**
```
T+0:00 - Application crashes (Python exception)
T+0:01 - Systemd detects exit
T+0:11 - Systemd restarts application (after 10 second delay)
T+0:12 - Application running again
```

**Scenario 2: Dependency failure**
```
T+0:00 - AWS API unreachable (network issue)
T+0:01 - Application exits (can't fetch secrets)
T+0:11 - Systemd restarts (network might be back)
T+0:12 - AWS API reachable → secrets fetched → application starts
```

**Why `RestartSec=10`:**
- Prevents restart loop (immediate repeated failures)
- Gives time for transient issues to resolve
- Reduces log spam (not restarting every second)

**Without restart policy:**
```
Application crashes → Service dead → Health checks fail → Instance removed from ALB → Manual intervention required
```

**With restart policy:**
```
Application crashes → Systemd restarts → Service recovers → Health checks pass → No manual intervention
```

**Security Hardening Directives**

```ini
NoNewPrivileges=true
```
- Process can't escalate privileges (can't become root)
- Even if exploit found, can't gain more permissions
- Defense in depth

```ini
PrivateTmp=true
```
- Application gets private `/tmp` directory
- Can't see other processes' temp files
- Prevents temp file attacks

```ini
ProtectSystem=strict
```
- Makes most of filesystem read-only
- Application can't modify system files
- Can only write to explicitly allowed paths

```ini
ReadWritePaths=/opt/rewards
```
- Exception to `ProtectSystem`
- Application can write to its own directory
- For `.env` file, logs, etc.

```ini
ProtectHome=true
```
- Makes `/home` inaccessible
- Application can't read user files
- Reduces attack surface

**Logging Configuration**

```ini
StandardOutput=journal
StandardError=journal
```
- Send stdout/stderr to systemd journal
- Centralized logging (all system services)
- View logs: `journalctl -u rewards-health -f`

```ini
SyslogIdentifier=rewards-health
```
- Tag logs with this identifier
- Makes filtering easier
- Example: `journalctl -t rewards-health`

**[Install] Section - Service Enablement**

```ini
WantedBy=multi-user.target
```
- Start service when system reaches "multi-user" target
- Equivalent to traditional "runlevel 3"
- Means: Start on boot (after basic system is up)

**Enable command creates symlink:**
```bash
systemctl enable rewards-health

Creates:
/etc/systemd/system/multi-user.target.wants/rewards-health.service
  → /etc/systemd/system/rewards-health.service
```

#### Task 5: Enable and Start Service

```yaml
- name: Enable and start rewards-health service
  systemd:
    name: rewards-health
    enabled: yes       # Start on boot
    state: started     # Ensure running now
    daemon_reload: yes # Reload systemd if unit file changed
```

**What it does:**
- Enables service (starts on boot)
- Starts service (running right now)
- Reloads systemd if unit file changed

**Equivalent commands:**
```bash
systemctl daemon-reload             # Reload systemd
systemctl enable rewards-health     # Start on boot
systemctl start rewards-health      # Start now
```

**State progression:**

**First run (service doesn't exist):**
```
1. daemon-reload (load new unit file)
2. enable (create symlink in multi-user.target.wants)
3. start (execute ExecStartPre + ExecStart)
Result: Service running, will start on boot
```

**Subsequent runs (service already running):**
```
If unit file unchanged:
  - enabled: yes → already enabled → ok
  - state: started → already started → ok
  Result: No changes

If unit file changed:
  - daemon-reload (reload new unit file)
  - enabled: yes → already enabled → ok
  - state: started → service running with old config → restart
  Result: Service restarted with new config
```

**Verify service:**
```bash
# Check status
systemctl status rewards-health

Output:
● rewards-health.service - Rewards Health Service
   Loaded: loaded (/etc/systemd/system/rewards-health.service; enabled)
   Active: active (running) since Sun 2026-03-16 14:30:00 UTC; 2h ago
 Main PID: 1234 (python3)
   Status: "Starting server on port 8080..."
   CGroup: /system.slice/rewards-health.service
           └─1234 /usr/bin/python3 /opt/rewards/health-service.py

# Check logs
journalctl -u rewards-health -f

Output:
Mar 16 14:30:00 rewards-health[1234]: Starting server on port 8080...
Mar 16 14:30:00 rewards-health[1234]: Environment: dev
Mar 16 14:30:00 rewards-health[1234]: Region: us-east-1
Mar 16 14:30:00 rewards-health[1234]: Commit: abc123def456
Mar 16 14:30:15 rewards-health[1234]: [16/Mar/2026 14:30:15] "GET /health HTTP/1.1" 200 -
```

**Health check verification:**
```bash
curl http://localhost:8080/health

Output:
{
  "service": "rewards",
  "status": "ok",
  "commit": "abc123def456",
  "region": "us-east-1",
  "environment": "dev"
}
```

---

### OBSERVABILITY ROLE: Monitoring Configuration

**Purpose:** Configure logging and monitoring for the application.

#### Task 1: Create Log Directory

```yaml
- name: Ensure application log directory exists
  file:
    path: /var/log/rewards
    state: directory
    owner: ec2-user
    group: ec2-user
    mode: '0755'
```

**What it does:**
- Creates `/var/log/rewards` directory
- Dedicated location for application logs
- Permissions: ec2-user can write, everyone can read

**Why `/var/log/rewards`:**
- `/var/log` = Linux standard for log files
- Separate from system logs (`/var/log/messages`)
- Easy to configure CloudWatch Logs agent (monitor specific directory)
- Clear organization (all rewards logs in one place)

#### Task 2: Configure Application Logging

```yaml
- name: Configure systemd to log to file
  lineinfile:
    path: /etc/systemd/system/rewards-health.service
    insertafter: '^\[Service\]'
    line: "StandardOutput=append:/var/log/rewards/health-service.log"
  notify: restart rewards-health
```

**What it does:**
- Modifies systemd unit file
- Redirects application output to log file
- Alternative to journald (binary logs)

**Why log to file:**
- Plain text logs (easier to grep/search)
- Can forward to CloudWatch Logs
- Persistent (journald may rotate/delete)
- Standard format for log aggregation tools

**Log output example:**

`/var/log/rewards/health-service.log`:
```
[2026-03-16 14:30:00] Starting server on port 8080...
[2026-03-16 14:30:00] Environment: dev
[2026-03-16 14:30:00] Region: us-east-1
[2026-03-16 14:30:00] Commit: abc123def456
[2026-03-16 14:30:15] GET /health HTTP/1.1 200 -
[2026-03-16 14:30:45] GET /health HTTP/1.1 200 -
[2026-03-16 14:31:15] GET /health HTTP/1.1 200 -
```

**CloudWatch Logs Integration (Future):**

```yaml
# Install CloudWatch Logs agent
- name: Install CloudWatch Logs agent
  yum:
    name: amazon-cloudwatch-agent
    state: present

# Configure log streaming
- name: Configure CloudWatch Logs
  template:
    src: cloudwatch-config.json.j2
    dest: /opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-config.json
  notify: restart cloudwatch-agent
```

**CloudWatch config:**
```json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/rewards/health-service.log",
            "log_group_name": "/aws/ec2/rewards/health-service",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
```

**Benefits:**
- Centralized logging (all instances → one place)
- Log aggregation (search across all instances)
- Log retention (30/60/90 days)
- CloudWatch Insights (SQL-like queries)
- Alarms (trigger on error patterns)

---

## 6. Idempotency in Practice

### What is Idempotency?

**Definition:** An operation that produces the same result no matter how many times it's executed.

**Mathematical analogy:**
```
f(x) = f(f(x))

Example:
abs(-5) = 5
abs(abs(-5)) = abs(5) = 5
abs(abs(abs(-5))) = 5
```

**In Ansible:**
```
run_playbook(servers) = "configured state"
run_playbook(run_playbook(servers)) = "configured state"
run_playbook^10(servers) = "configured state"
```

### Why Idempotency Matters

**Benefits:**
- ✅ Safe to run repeatedly (automation, cron jobs)
- ✅ Self-healing (correct configuration drift)
- ✅ Predictable outcomes (always same result)
- ✅ No side effects (won't break things)
- ✅ Can resume after failures (no cleanup needed)

**Without idempotency:**
```
Run 1: Works ✓
Run 2: Breaks (duplicate entries) ✗
Run 3: Fails (conflicts) ✗
```

**With idempotency:**
```
Run 1: Changes applied ✓
Run 2: Already correct, no changes ✓
Run 3: Still correct, no changes ✓
```

### Non-Idempotent Examples (Anti-patterns)

#### Example 1: Append to File

**Bad (Not Idempotent):**
```bash
#!/bin/bash
echo "PASSWORD=secret123" >> /etc/secrets.conf
```

**Result:**
```
Run 1: /etc/secrets.conf contains:
PASSWORD=secret123

Run 2: /etc/secrets.conf contains:
PASSWORD=secret123
PASSWORD=secret123

Run 3: /etc/secrets.conf contains:
PASSWORD=secret123
PASSWORD=secret123
PASSWORD=secret123
```
❌ Each run adds duplicate line

**Good (Idempotent):**
```yaml
- name: Set password in config
  lineinfile:
    path: /etc/secrets.conf
    regexp: '^PASSWORD='
    line: 'PASSWORD=secret123'
```

**Result:**
```
Run 1: File changed (line added)
Run 2: File unchanged (line already correct)
Run 3: File unchanged (line already correct)
```
✅ Same result every time

#### Example 2: Create User

**Bad (Not Idempotent):**
```bash
#!/bin/bash
useradd appuser
```

**Result:**
```
Run 1: User created ✓
Run 2: ERROR: user 'appuser' already exists ✗
```
❌ Script fails on second run

**Good (Idempotent):**
```yaml
- name: Ensure application user exists
  user:
    name: appuser
    state: present
```

**Result:**
```
Run 1: User created → changed
Run 2: User already exists → ok
Run 3: User already exists → ok
```
✅ Works every time

#### Example 3: Install Package

**Bad (Not Idempotent):**
```bash
#!/bin/bash
yum install python3
# Returns different exit codes based on state
```

**Good (Idempotent):**
```yaml
- name: Ensure Python 3 is installed
  yum:
    name: python3
    state: present
```

**How Ansible achieves idempotency:**
```
1. Check current state: Is python3 installed?
2. Compare to desired state: Should python3 be installed?
3. If different: Install python3 → report "changed"
4. If same: Do nothing → report "ok"
```

### Idempotency in Our Playbook

**Running the same playbook multiple times:**

```bash
# First run (fresh instance)
ansible-playbook -i inventory/aws_ec2.yml playbook.yml

PLAY [Configure rewards instances] ****

TASK [common : Update packages] ****
changed: [i-0a1b2c3d] => 15 packages updated

TASK [common : Install required packages] ****
changed: [i-0a1b2c3d] => Installed: chrony, logrotate, python3

TASK [common : Enable chrony] ****
changed: [i-0a1b2c3d] => Service enabled and started

TASK [health-service : Deploy application] ****
changed: [i-0a1b2c3d] => File created

TASK [health-service : Enable service] ****
changed: [i-0a1b2c3d] => Service enabled and started

RECAP ****
i-0a1b2c3d : ok=15 changed=12 unreachable=0 failed=0 skipped=0
```

**Second run (already configured):**

```bash
ansible-playbook -i inventory/aws_ec2.yml playbook.yml

PLAY [Configure rewards instances] ****

TASK [common : Update packages] ****
ok: [i-0a1b2c3d] => No updates available

TASK [common : Install required packages] ****
ok: [i-0a1b2c3d] => Packages already installed

TASK [common : Enable chrony] ****
ok: [i-0a1b2c3d] => Service already enabled and running

TASK [health-service : Deploy application] ****
ok: [i-0a1b2c3d] => File already correct

TASK [health-service : Enable service] ****
ok: [i-0a1b2c3d] => Service already enabled and running

RECAP ****
i-0a1b2c3d : ok=15 changed=0 unreachable=0 failed=0 skipped=0
```

**Key observations:**
- **First run:** 12 tasks reported `changed` (configuration applied)
- **Second run:** 0 tasks reported `changed` (everything already correct)
- **Result:** Same system state, no unintended side effects

**Configuration drift correction:**

Imagine an engineer manually modified SSH config:

```bash
# Engineer manually changes config
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
```

**Next Ansible run:**
```
TASK [common : Disable SSH password authentication] ****
changed: [i-0a1b2c3d] => File modified (corrected)

Handler triggered:
HANDLER [restart sshd] ****
changed: [i-0a1b2c3d] => Service restarted with correct config
```

**Result:** Configuration drift automatically corrected ✅

---

## 7. Workflow: How It All Works Together

### Scenario 1: Initial Deployment

**Complete deployment workflow from scratch:**

```
┌─────────────────────────────────────────────────────────────┐
│ Step 1: Terraform Provisions Infrastructure                 │
└─────────────────────────────────────────────────────────────┘
  │
  ├─ terraform apply
  │
  ├─ Creates VPC, subnets, security groups
  ├─ Creates ALB and target group
  ├─ Creates IAM roles and policies
  ├─ Launches EC2 instance (bare Amazon Linux 2023)
  │
  └─ User data script runs:
      ├─ Updates system packages
      ├─ Installs SSM agent
      ├─ Applies instance tags (Environment=dev, Service=rewards)
      └─ Signals completion to CloudFormation/Terraform

┌─────────────────────────────────────────────────────────────┐
│ Step 2: Instance Ready for Configuration                    │
└─────────────────────────────────────────────────────────────┘
  │
  └─ Instance state:
      ├─ Running in private subnet
      ├─ SSM agent connected to AWS
      ├─ No application installed
      ├─ No services configured
      └─ Security baseline not applied

┌─────────────────────────────────────────────────────────────┐
│ Step 3: CI/CD Triggers Ansible                              │
└─────────────────────────────────────────────────────────────┘
  │
  ├─ GitHub Actions workflow triggered
  │   ├─ Event: terraform apply completed
  │   └─ Job: configure-instances
  │
  └─ Ansible playbook execution:
      ansible-playbook -i inventory/aws_ec2.yml playbook.yml

┌─────────────────────────────────────────────────────────────┐
│ Step 4: Dynamic Inventory Discovery                         │
└─────────────────────────────────────────────────────────────┘
  │
  ├─ Ansible queries AWS API
  │   └─ Filters: tag:Environment=dev, tag:Service=rewards
  │
  ├─ Discovers instances:
  │   └─ i-0a1b2c3d4e5f6g7h8 (10.0.2.45)
  │
  └─ Creates inventory groups:
      ├─ env_dev
      └─ service_rewards

┌─────────────────────────────────────────────────────────────┐
│ Step 5: Ansible Connects via SSM                            │
└─────────────────────────────────────────────────────────────┘
  │
  ├─ Ansible uses AWS SSM connection plugin
  ├─ Authenticates with IAM credentials
  ├─ SSM creates encrypted tunnel to instance
  └─ Ready to execute tasks

┌─────────────────────────────────────────────────────────────┐
│ Step 6: Common Role - Security Baseline                     │
└─────────────────────────────────────────────────────────────┘
  │
  ├─ Update all packages (security patches)
  ├─ Install required packages (chrony, logrotate, python3)
  ├─ Enable and start chronyd (time synchronization)
  ├─ Harden SSH configuration (disable password auth)
  ├─ Configure log rotation (prevent disk fill)
  └─ Result: Secure, consistent baseline

┌─────────────────────────────────────────────────────────────┐
│ Step 7: Health-Service Role - Deploy Application           │
└─────────────────────────────────────────────────────────────┘
  │
  ├─ Create application directory (/opt/rewards)
  ├─ Deploy secret fetch script (fetch-secrets.sh)
  ├─ Deploy health service application (health-service.py)
  ├─ Deploy systemd unit file (rewards-health.service)
  ├─ Enable and start service
  │   ├─ ExecStartPre: Fetch secrets from SSM
  │   ├─ Load environment variables from .env
  │   └─ Start Python application on port 8080
  └─ Result: Application running and healthy

┌─────────────────────────────────────────────────────────────┐
│ Step 8: Observability Role - Configure Monitoring          │
└─────────────────────────────────────────────────────────────┘
  │
  ├─ Create log directory (/var/log/rewards)
  ├─ Configure application logging (file output)
  ├─ (Future) Install CloudWatch agent
  └─ Result: Logs captured, monitoring ready

┌─────────────────────────────────────────────────────────────┐
│ Step 9: ALB Health Checks Begin                            │
└─────────────────────────────────────────────────────────────┘
  │
  ├─ ALB sends: GET http://instance:8080/health
  ├─ Application responds: {"service":"rewards","status":"ok",...}
  ├─ Health check passes (HTTP 200)
  └─ After 2 consecutive successes: Instance marked healthy

┌─────────────────────────────────────────────────────────────┐
│ Step 10: Instance Registered with ALB                      │
└─────────────────────────────────────────────────────────────┘
  │
  ├─ Instance added to ALB target group
  ├─ Begins receiving production traffic
  └─ Deployment complete ✅

Total time: ~3-5 minutes (Terraform: 2-3 min, Ansible: 1-2 min)
```

### Scenario 2: Auto Scaling Instance Replacement

**Timeline: New instance launched by Auto Scaling Group**

```
T+0:00  Auto Scaling Decision
        ├─ Scheduled scale-up OR
        ├─ Existing instance unhealthy OR
        └─ Manual scaling action
        
        ASG launches new EC2 instance

T+0:30  Instance Boot Complete
        ├─ Amazon Linux 2023 boots
        ├─ User data script executes
        ├─ SSM agent installed and connected
        └─ Instance tags applied

T+1:00  CI/CD Detects New Instance
        ├─ EventBridge rule: EC2 Instance State Change
        ├─ OR periodic Ansible run (cron schedule)
        └─ GitHub Actions workflow triggered

T+1:05  Ansible Dynamic Inventory Query
        ├─ Queries AWS: Find instances with tags
        ├─ Discovers new instance: i-1b2c3d4e5f6g7h8i9
        └─ Adds to inventory automatically

T+1:10  Ansible Configuration Begins
        ├─ Connects via SSM (no SSH needed)
        ├─ Applies common role (security baseline)
        ├─ Applies health-service role (deploy app)
        └─ Applies observability role (configure logs)

T+2:00  Application Started
        ├─ Systemd starts rewards-health.service
        ├─ ExecStartPre fetches secrets from SSM
        ├─ Application starts on port 8080
        └─ Health endpoint responding

T+2:30  ALB Health Checks Pass
        ├─ First health check: 200 OK (1/2)
        ├─ Second health check: 200 OK (2/2)
        └─ Instance marked healthy

T+3:00  Instance In Service
        ├─ ALB adds to target group
        ├─ Begins receiving production traffic
        └─ Fully operational ✅

Total time: ~3 minutes (fully automated, zero manual intervention)
```

**Compare to manual process:**
```
Without Ansible:
T+0:00  Instance launches
T+0:30  Instance boots
T+1:00  Engineer notices new instance
T+1:30  Engineer SSHs into instance
T+2:00  Engineer manually installs packages
T+2:30  Engineer manually configures application
T+3:00  Engineer manually starts service
T+3:30  Engineer debugs issues
T+5:00  Maybe working? Who knows.
```

### Scenario 3: Configuration Update (Change SSH Settings)

**Workflow: Update SSH hardening across all instances**

```
┌─────────────────────────────────────────────────────────────┐
│ Step 1: Developer Updates Ansible Role                      │
└─────────────────────────────────────────────────────────────┘
  │
  └─ Edit roles/common/tasks/main.yml:
      Add: PermitRootLogin no
      Add: MaxAuthTries 3

┌─────────────────────────────────────────────────────────────┐
│ Step 2: Code Review & Merge                                 │
└─────────────────────────────────────────────────────────────┘
  │
  ├─ Create pull request
  ├─ Team reviews changes
  ├─ Tests pass (syntax check, lint)
  └─ Merge to main branch

┌─────────────────────────────────────────────────────────────┐
│ Step 3: CI/CD Executes Ansible                             │
└─────────────────────────────────────────────────────────────┘
  │
  ├─ GitHub Actions triggered on merge
  └─ Run: ansible-playbook -i inventory/aws_ec2.yml playbook.yml

┌─────────────────────────────────────────────────────────────┐
│ Step 4: Ansible Discovers All Instances                    │
└─────────────────────────────────────────────────────────────┘
  │
  └─ Dynamic inventory finds:
      ├─ i-0a1b2c3d (us-east-1a)
      ├─ i-1b2c3d4e (us-east-1a)
      └─ i-2c3d4e5f (us-east-1b)

┌─────────────────────────────────────────────────────────────┐
│ Step 5: Configuration Applied to All Instances             │
└─────────────────────────────────────────────────────────────┘
  │
  ├─ Instance i-0a1b2c3d:
  │   ├─ SSH config updated → changed
  │   └─ Handler triggered: restart sshd
  │
  ├─ Instance i-1b2c3d4e:
  │   ├─ SSH config updated → changed
  │   └─ Handler triggered: restart sshd
  │
  └─ Instance i-2c3d4e5f:
      ├─ SSH config updated → changed
      └─ Handler triggered: restart sshd

┌─────────────────────────────────────────────────────────────┐
│ Step 6: Verification                                        │
└─────────────────────────────────────────────────────────────┘
  │
  └─ All instances now have:
      ├─ PermitRootLogin no
      ├─ MaxAuthTries 3
      ├─ PasswordAuthentication no
      └─ Configuration consistent across fleet

Total time: ~30 seconds for 3 instances (parallel execution)
```

**Benefits demonstrated:**
- ✅ One source of truth (Git)
- ✅ Audit trail (Git history)
- ✅ Consistent application (all instances identical)
- ✅ Parallel execution (fast)
- ✅ Rollback capability (git revert)

### Scenario 4: Application Deployment Update

**Workflow: Deploy new version of health-service**

```
┌─────────────────────────────────────────────────────────────┐
│ Step 1: Update Application Code                             │
└─────────────────────────────────────────────────────────────┘
  │
  └─ Edit roles/health-service/templates/health-service.py.j2
      Add: New /metrics endpoint
      Add: Prometheus metrics export

┌─────────────────────────────────────────────────────────────┐
│ Step 2: Update Environment Variables                        │
└─────────────────────────────────────────────────────────────┘
  │
  └─ Update GIT_COMMIT variable in CI/CD
      Old: abc123def456
      New: def789ghi012

┌─────────────────────────────────────────────────────────────┐
│ Step 3: CI/CD Deploys Update                               │
└─────────────────────────────────────────────────────────────┘
  │
  └─ ansible-playbook executed

┌─────────────────────────────────────────────────────────────┐
│ Step 4: Rolling Update (Instance by Instance)              │
└─────────────────────────────────────────────────────────────┘
  │
  ├─ Instance 1:
  │   ├─ Deploy new health-service.py → changed
  │   ├─ Handler triggered: restart rewards-health
  │   ├─ Service restarts (~2 seconds downtime)
  │   └─ Health checks pass (new version running)
  │
  ├─ Instance 2:
  │   ├─ Deploy new health-service.py → changed
  │   ├─ Handler triggered: restart rewards-health
  │   ├─ Service restarts (~2 seconds downtime)
  │   └─ Health checks pass
  │
  └─ Instance 3:
      ├─ Deploy new health-service.py → changed
      ├─ Handler triggered: restart rewards-health
      ├─ Service restarts (~2 seconds downtime)
      └─ Health checks pass

┌─────────────────────────────────────────────────────────────┐
│ Step 5: Verify Deployment                                  │
└─────────────────────────────────────────────────────────────┘
  │
  └─ Check health endpoint:
      curl http://alb-dns/health
      {
        "service": "rewards",
        "status": "ok",
        "commit": "def789ghi012",  ← New version!
        "region": "us-east-1"
      }

Total downtime: ~6 seconds (3 instances × 2 seconds each)
User impact: Minimal (ALB routes around restarting instances)
```

**Compare to Terraform-only approach:**
```
Terraform approach:
├─ Update user-data script
├─ terraform apply
├─ Destroy ALL instances
├─ Create NEW instances
├─ Wait for provisioning (2-3 minutes)
└─ Total downtime: 3-5 minutes (complete outage)

Ansible approach:
├─ Update application code
├─ ansible-playbook
├─ Rolling restart (keep instances running)
├─ Minimal downtime per instance
└─ Total downtime: 6 seconds (no complete outage)
```

---

## 8. Production Benefits

### Automation Benefits

#### Speed: 2-3 Minutes vs 30+ Minutes Manual

**Manual Configuration (Traditional Approach):**
```
Time required to configure ONE instance manually:

T+0:00  SSH into instance
T+0:30  Update packages (yum update)
T+2:00  Install dependencies
T+3:00  Download application code
T+4:00  Configure systemd service
T+5:00  Fetch secrets from SSM
T+6:00  Start application
T+7:00  Configure logging
T+8:00  Test health endpoint
T+10:00 Troubleshoot issues
T+15:00 Instance ready (if lucky)

For 3 instances: 45 minutes
For 10 instances: 2.5 hours
```

**Ansible Automation:**
```
Time required to configure ANY number of instances:

T+0:00  Run ansible-playbook
T+2:00  All instances configured

For 3 instances: 2 minutes
For 10 instances: 2 minutes (parallel execution)
For 100 instances: 3-4 minutes
```

**Productivity gain:**
- 1 instance: 13 minutes saved (87% faster)
- 10 instances: 2.5 hours saved (98% faster)
- Annually (with frequent updates): Hundreds of hours saved

#### Consistency: Zero Snowflakes

**Problem: Configuration Drift (Snowflake Servers)**

```
Week 1: All servers identical
  ├─ Python 3.9
  ├─ App version 1.0
  └─ SSH config A

Week 4: Server 1 manually modified
  ├─ Python 3.9
  ├─ App version 1.1 (manually updated)
  └─ SSH config A

Week 8: Server 2 different
  ├─ Python 3.10 (someone upgraded)
  ├─ App version 1.0
  └─ SSH config B (hardened manually)

Week 12: Server 3 also different
  ├─ Python 3.9
  ├─ App version 1.2 (different from others)
  └─ SSH config A

Result: Three "snowflake" servers - each unique
Problem: Debugging nightmare, unpredictable behavior
```

**Solution: Ansible Enforces Consistency**

```
Every Ansible run:
├─ Checks current state
├─ Compares to desired state (code)
├─ Corrects any differences
└─ Result: All servers identical

Week 1: All servers identical ✓
Week 4: Manual change detected and corrected ✓
Week 8: All servers still identical ✓
Week 12: All servers still identical ✓

Result: Zero snowflakes
Benefit: Predictable behavior, easier debugging
```

#### Documentation: Living, Executable Documentation

**Traditional Documentation (Outdated Within Days):**

```markdown
# Server Setup Guide

1. SSH into server
2. Run: yum update -y
3. Install packages: yum install python3 chrony
4. Edit /etc/ssh/sshd_config:
   - Set PasswordAuthentication no
   - Set PermitRootLogin no
5. ...

Problems:
❌ Gets outdated (someone forgets to update docs)
❌ Manual steps (typos, missed steps)
❌ No validation (did you really do step 4?)
❌ No audit trail (who made this change?)
```

**Ansible as Documentation (Always Accurate):**

```yaml
# roles/common/tasks/main.yml
- name: Update all packages
  yum:
    name: '*'
    state: latest

- name: Install required packages
  yum:
    name:
      - python3
      - chrony
    state: present

Benefits:
✅ Self-documenting (code IS documentation)
✅ Always accurate (code = reality)
✅ Executable (docs that run themselves)
✅ Version controlled (Git history = audit trail)
```

**When debugging:**
```
Traditional: "What's installed on this server?"
  → Check documentation (probably outdated)
  → SSH and manually inspect
  → Hope documentation matches reality

Ansible: "What's installed on this server?"
  → Read playbook (definitive source)
  → Playbook guarantees current state
  → 100% accurate documentation
```

#### Audit Trail: Every Change Tracked in Git

**Git History as Audit Log:**

```bash
git log --oneline roles/common/

def789g Update SSH hardening (added MaxAuthTries)
abc123d Add logrotate configuration
456xyz1 Initial common role setup
```

**Each commit shows:**
- **What changed:** Exact configuration differences
- **Who changed it:** Developer name and email
- **When:** Timestamp
- **Why:** Commit message explaining rationale

**Example commit:**
```
commit def789ghi012
Author: Alice Engineer <alice@example.com>
Date:   Mon Mar 15 14:30:00 2026

    Add SSH hardening: limit authentication attempts

    - Set MaxAuthTries to 3
    - Prevents brute force attacks
    - Compliance requirement from security audit

    Related: SEC-456
```

**Benefits:**
- Complete change history
- Accountability (who made this change?)
- Rationale (why was this changed?)
- Rollback capability (revert to any previous state)
- Compliance (prove configuration at any point in time)

#### Debugging: Playbooks Show Exact Configuration

**Traditional: Mystery Configurations**
```
Problem: Service not starting
Question: What's the systemd config?

Manual approach:
1. SSH to server
2. cat /etc/systemd/system/rewards-health.service
3. Is this the intended config?
4. Compare to other servers
5. Hope they're all the same
6. 30 minutes later...
```

**Ansible: Single Source of Truth**
```
Problem: Service not starting
Question: What's the systemd config?

Ansible approach:
1. Open roles/health-service/templates/rewards-health.service.j2
2. See EXACT configuration
3. This IS what's deployed
4. Know immediately what should be running
5. 30 seconds later...
```

#### Testable: Test in Dev Before Production

**Environment progression:**

```
┌─────────────────────────────────────────────────────────────┐
│ Development Environment                                      │
├─────────────────────────────────────────────────────────────┤
│ • Run playbook: ansible-playbook -e env=dev playbook.yml   │
│ • Test new configuration                                     │
│ • Verify nothing breaks                                      │
│ • Cost: $10/month                                           │
└─────────────────────────────────────────────────────────────┘
                         ↓ If successful
┌─────────────────────────────────────────────────────────────┐
│ Staging Environment                                          │
├─────────────────────────────────────────────────────────────┤
│ • Same playbook: ansible-playbook -e env=staging            │
│ • Production-like environment                                │
│ • Final validation                                           │
│ • Cost: $50/month                                           │
└─────────────────────────────────────────────────────────────┘
                         ↓ If successful
┌─────────────────────────────────────────────────────────────┐
│ Production Environment                                       │
├─────────────────────────────────────────────────────────────┤
│ • Same playbook: ansible-playbook -e env=prod               │
│ • Confidence: Already tested in dev + staging               │
│ • Risk: Minimal (same code, tested)                         │
│ • Cost: $500/month                                          │
└─────────────────────────────────────────────────────────────┘
```

**Same code, different environment:**
```yaml
# Playbook adapts to environment
- hosts: "tag_Environment_{{ env }}"
  vars_files:
    - "vars/{{ env }}.yml"
  roles:
    - common
    - health-service
```

**Benefit:** Catch issues in dev, not in production

#### Scaling: Configure 1 or 100 Servers, Same Effort

**Manual Scaling Challenge:**
```
1 server: 30 minutes
5 servers: 2.5 hours
10 servers: 5 hours
100 servers: 50 hours (2 full weeks!)
```

**Ansible Scaling Advantage:**
```
1 server: 2 minutes
5 servers: 2 minutes (parallel)
10 servers: 2 minutes (parallel)
100 servers: 3-4 minutes (parallel)

Ansible runs on multiple hosts simultaneously!
```

**Parallel execution example:**
```yaml
# ansible.cfg
[defaults]
forks = 10  # Configure 10 servers at once

# Run playbook
ansible-playbook playbook.yml

Result:
├─ Batch 1: Instances 1-10 (simultaneous)
├─ Batch 2: Instances 11-20 (simultaneous)
└─ ...

Time remains constant regardless of fleet size!
```

### Risk Reduction

#### No "Oops" Moments: Can't Forget a Step

**Manual Process:**
```
Step 1: Update packages ✓
Step 2: Install Python ✓
Step 3: Configure SSH ✓
Step 4: Enable chrony ✗ (forgot!)
Step 5: Deploy application ✓

Result: Time drift → API failures in 2 weeks
```

**Ansible Process:**
```
Task 1: Update packages → runs automatically
Task 2: Install Python → runs automatically
Task 3: Configure SSH → runs automatically
Task 4: Enable chrony → runs automatically
Task 5: Deploy application → runs automatically

Result: All steps completed every time
```

**Can't forget because:**
- Playbook defines ALL steps
- Steps execute in order automatically
- No human memory required
- Consistent every time

#### No Manual Errors: Typos Impossible

**Manual Errors:**
```bash
# Typo in command
systemct1 enable chronyd  ← typo: systemct1
-bash: systemct1: command not found

# Wrong path
cp app.py /otp/rewards/  ← typo: /otp instead of /opt
# Application broken, debugging takes hours

# Wrong permissions
chmod 777 /opt/rewards  ← security vulnerability
# Exposed to all users
```

**Ansible Prevents:**
```yaml
- name: Enable chrony
  systemd:
    name: chronyd
    state: started
    enabled: yes
```
- Module name validated (can't typo)
- Parameters validated (can't typo)
- Paths validated (can't typo)
- Permissions enforced (can't fat-finger)

#### No Knowledge Silos: Anyone Can Read Playbook

**Problem: "Bob knows how this works"**
```
Scenario:
├─ Bob configured all servers manually
├─ Bob remembers special settings
├─ Bob's knowledge is in his head
├─ Bob on vacation = no one can deploy
└─ Bob leaves company = knowledge GONE
```

**Solution: Knowledge in Code**
```
Scenario:
├─ Configuration in Ansible playbooks
├─ Anyone can read roles/
├─ New team member can understand in hours
├─ Bob on vacation = playbook still works
└─ Bob leaves = knowledge preserved in Git
```

**Onboarding new engineer:**
```
Traditional:
├─ Shadow Bob for 2 weeks
├─ Take notes
├─ Hope you remembered everything
└─ Ready after 1 month

Ansible:
├─ Read playbook (1-2 hours)
├─ Understand exactly what's deployed
├─ Can make changes confidently
└─ Ready after 1 day
```

#### Testable: Run on Test Environment First

**Testing workflow:**
```
1. Make change to playbook
2. Run on test instance:
   ansible-playbook -i test_inventory playbook.yml
3. Verify:
   ✓ Service starts
   ✓ Health check passes
   ✓ No errors in logs
4. If successful, run on production
5. If failed, fix and retry (test instance = disposable)
```

**Risk mitigation:**
- Find bugs in test, not production
- Test instance can break (it's test!)
- No customer impact from experiments
- Iterate quickly until working

#### Rollback: Git Revert = Instant Rollback

**Problem Scenario:**
```
New configuration deployed
  ↓
Service crashes
  ↓
Need to rollback FAST
```

**Ansible + Git Rollback:**
```bash
# Identify bad commit
git log --oneline
def789g Latest changes (BROKEN)
abc123d Previous version (working)

# Revert to previous version
git revert def789g

# Deploy old (working) configuration
ansible-playbook playbook.yml

# Service restored
Time: 2-3 minutes
```

**Compare to manual rollback:**
```
Manual approach:
├─ What was the old configuration?
├─ Check documentation (if it exists)
├─ SSH to each server
├─ Manually revert changes
├─ Hope you got everything
└─ Time: 30-60 minutes + stress
```

#### Disaster Recovery: Rebuild from Code

**Disaster Scenario: Entire Region Lost**

```
Problem:
├─ AWS us-east-1 region catastrophic failure
├─ All instances gone
├─ All data gone
└─ Need to rebuild in us-west-2
```

**Traditional Recovery:**
```
1. Find documentation (where is it?)
2. Manually rebuild each server
3. Hope documentation is accurate
4. Manual configuration (error-prone)
5. Days to weeks to fully recover
```

**Ansible Recovery:**
```
1. Update Terraform: region = "us-west-2"
2. terraform apply (creates infrastructure)
3. ansible-playbook playbook.yml (configures instances)
4. Result: Identical environment in new region
5. Time: 10-15 minutes

Complete disaster recovery from code!
```

**Benefits:**
- Infrastructure as code (Terraform)
- Configuration as code (Ansible)
- Both in Git (backed up, versioned)
- Can rebuild anywhere, anytime
- Tested regularly (use in dev/staging)

---

## 9. Key Takeaways

### When to Use Terraform

**Terraform is best for:**

✅ **Creating cloud resources:**
- VPC, subnets, routing tables
- EC2 instances, Auto Scaling Groups
- RDS databases, S3 buckets
- Load balancers, security groups
- IAM roles, policies, users

✅ **Infrastructure lifecycle:**
- Create: Provision new resources
- Update: Modify resource configurations
- Destroy: Clean up resources
- State tracking: Know what exists

✅ **Cloud-agnostic provisioning:**
- AWS, Azure, GCP
- Same tool, different providers
- Consistent workflow

**Example Terraform use:**
```hcl
# Create EC2 instance
resource "aws_instance" "app" {
  ami           = "ami-12345"
  instance_type = "t4g.nano"
  subnet_id     = aws_subnet.private.id
}

# Terraform handles:
# - API calls to AWS
# - Resource dependencies
# - State management
# - Resource lifecycle
```

### When to Use Ansible

**Ansible is best for:**

✅ **Configuring servers:**
- Install packages and dependencies
- Configure system settings
- Manage users and permissions
- Configure services (SSH, NTP, etc.)

✅ **Deploying applications:**
- Copy application code
- Configure application settings
- Start/stop services
- Manage application lifecycle

✅ **Configuration management:**
- Ensure desired state
- Correct configuration drift
- Apply security policies
- Enforce standards

✅ **Ad-hoc operational tasks:**
- Restart services across fleet
- Gather system information
- Run maintenance scripts
- Emergency fixes

**Example Ansible use:**
```yaml
# Configure server
- name: Install and configure web server
  block:
    - name: Install nginx
      yum:
        name: nginx
        state: present
    
    - name: Deploy nginx config
      template:
        src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf
    
    - name: Start nginx
      systemd:
        name: nginx
        state: started
        enabled: yes

# Ansible handles:
# - Current state checking
# - Idempotent operations
# - Configuration deployment
# - Service management
```

### Together: Complete Infrastructure Automation

**The Power of Terraform + Ansible:**

```
┌──────────────────────────────────────────────────────────┐
│ Complete Infrastructure Automation Stack                  │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Terraform (Infrastructure as Code)                 │  │
│  │                                                     │  │
│  │ • Creates AWS resources                            │  │
│  │ • Manages infrastructure lifecycle                 │  │
│  │ • Tracks state                                     │  │
│  │ • Handles dependencies                             │  │
│  └────────────────────────────────────────────────────┘  │
│                          ↓                                │
│               "Bare infrastructure exists"                │
│                          ↓                                │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Ansible (Configuration as Code)                    │  │
│  │                                                     │  │
│  │ • Configures servers                               │  │
│  │ • Deploys applications                             │  │
│  │ • Manages configuration drift                      │  │
│  │ • Enforces desired state                           │  │
│  └────────────────────────────────────────────────────┘  │
│                          ↓                                │
│            "Configured, running application"              │
│                                                            │
└──────────────────────────────────────────────────────────┘

Both:
✓ Version controlled (Git)
✓ Code reviewed (Pull Requests)
✓ Tested (CI/CD)
✓ Documented (code = documentation)
✓ Auditable (Git history)
✓ Repeatable (run anywhere)
```

### Architecture Pattern Summary

**Our Three-Tier Automation:**

1. **Infrastructure (Terraform):**
   - VPC: `10.0.0.0/16`
   - Subnets: Public + private across 2 AZs
   - Security groups: ALB + application
   - ALB: Internet-facing, health checks
   - EC2: Auto Scaling Group, t4g.nano
   - IAM: Least privilege roles

2. **Configuration (Ansible):**
   - Common role: Security baseline
   - Health-service role: Application deployment
   - Observability role: Logging and monitoring
   - SSM connection: No SSH, no bastion
   - Dynamic inventory: Auto-discovery

3. **CI/CD (GitHub Actions):**
   - Terraform workflow: Infrastructure changes
   - Ansible workflow: Configuration changes
   - OIDC authentication: No long-lived credentials
   - Branch protection: Code review required
   - Automated testing: Syntax, lint, validate

**Result:**
- **Complete automation:** Infrastructure + configuration
- **Self-documenting:** Code explains itself
- **Self-healing:** Auto Scaling + Ansible
- **Auditable:** Git history + CloudTrail
- **Secure:** Least privilege, no secrets in code
- **Cost-effective:** ~$35-60/month for dev environment
- **Production-ready:** Same pattern scales to production

### Final Thoughts

**What We've Learned:**

1. **Ansible is powerful:** Agentless, declarative, idempotent configuration management

2. **Terraform and Ansible are complementary:** Infrastructure + configuration = complete automation

3. **Separation of concerns matters:** Clear boundaries between tools and teams

4. **Idempotency enables confidence:** Safe to run repeatedly, self-healing infrastructure

5. **Code is better than documentation:** Executable, accurate, version-controlled

6. **Automation reduces risk:** Eliminates manual errors, provides rollback, enables testing

7. **Dynamic inventory is essential:** Auto-discovery works with Auto Scaling

8. **Security in layers:** SSM instead of SSH, secrets in SSM Parameter Store, least privilege IAM

**Next Steps:**

1. **Explore the code:**
   - [`ansible/playbook.yml`](../ansible/playbook.yml) - Main playbook
   - [`ansible/roles/`](../ansible/roles/) - Role definitions
   - [`ansible/inventory/aws_ec2.yml`](../ansible/inventory/aws_ec2.yml) - Dynamic inventory

2. **Run in your environment:**
   - Set up AWS credentials
   - Configure SSM connection
   - Run playbook on test instance

3. **Experiment and learn:**
   - Make changes to roles
   - Run playbook and observe changes
   - Break things in test (safe to fail!)

4. **Extend the architecture:**
   - Add CloudWatch agent role
   - Implement blue-green deployment
   - Add application monitoring
   - Set up centralized logging

**Remember:**
- Start simple, iterate
- Test everything
- Document decisions (in code!)
- Security first
- Automate everything

---

**Additional Resources:**

- [Official Ansible Documentation](https://docs.ansible.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [AWS SSM Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [Infrastructure as Code Patterns](https://www.oreilly.com/library/view/infrastructure-as-code/9781098114664/)
- [Project SOLUTION.md](./SOLUTION.md) - Complete architecture documentation

---

**Document Version:** 1.0
**Last Updated:** March 2026
**Maintained By:** Neal Street Technologies Engineering Team