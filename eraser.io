title Project‑5 • VPC Networking (3 AZs, Public over Private, NAT options)

// VPC container
AWS VPC [icon: aws-vpc, label: "AWS VPC (project-5, 10.0.0.0/16)", color: blue] {
  // Put IGW first so it renders above the AZs
  IGW [icon: aws-internet-gateway, label: "Internet Gateway (IGW)"]

  // AZs declared in order to encourage side‑by‑side layout
  AZ1 [label: "AZ1"] {
    // Top box in AZ1
    AZ1 Public  [icon: aws-subnet-public,  label: "Public Subnet (AZ1)"] {
      NAT AZ1 [icon: aws-nat-gateway, label: "NAT Gateway (AZ1) • EIP"]
    }
    // Bottom box in AZ1
    AZ1 Private [icon: aws-subnet-private, label: "Private Subnet (AZ1)"]
  }

  AZ2 [label: "AZ2"] {
    AZ2 Public  [icon: aws-subnet-public,  label: "Public Subnet (AZ2)"] {
      NAT AZ2 [icon: aws-nat-gateway, label: "NAT Gateway (AZ2) • optional"]
    }
    AZ2 Private [icon: aws-subnet-private, label: "Private Subnet (AZ2)"]
  }

  AZ3 [label: "AZ3"] {
    AZ3 Public  [icon: aws-subnet-public,  label: "Public Subnet (AZ3)"] {
      NAT AZ3 [icon: aws-nat-gateway, label: "NAT Gateway (AZ3) • optional"]
    }
    AZ3 Private [icon: aws-subnet-private, label: "Private Subnet (AZ3)"]
  }
}

// Public subnet routing (up to IGW)
AZ1 Public > IGW: 0.0.0.0/0
AZ2 Public > IGW: 0.0.0.0/0
AZ3 Public > IGW: 0.0.0.0/0

// Private subnet routing (per‑AZ NAT mode)
AZ1 Private > NAT AZ1: 0.0.0.0/0
AZ2 Private > NAT AZ2: 0.0.0.0/0
AZ3 Private > NAT AZ3: 0.0.0.0/0

// Private subnet routing (single‑NAT mode; dashed = conditional)
// Lines terminate on the NAT **inside** AZ1 Public (not the AZ border)
AZ2 Private --> NAT AZ1: 0.0.0.0/0 (single‑NAT)
AZ3 Private --> NAT AZ1: 0.0.0.0/0 (single‑NAT)

// Layout hints (comments only; not nodes):
// - IGW first keeps it centered above the AZs.
// - Each AZ contains two stacked boxes: Public (top), Private (bottom).
// - AZ1/AZ2/AZ3 render side‑by‑side because they’re siblings in this order.
// - Solid arrows = per‑AZ NAT; dashed arrows = single‑NAT to AZ1.
