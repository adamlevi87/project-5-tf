
<img width="8192" height="3983" alt="project5" src="https://github.com/user-attachments/assets/9aa2948f-daef-4cbc-a851-a05cf7c3e303" />


**In the Terraform repository**, manually create the following GitHub secrets and variable (one-time setup):

   * A **secret** named `TOKEN_GITHUB`. The value should be a GitHub PAT - fine-grained with access to the Application repository and with specific permissions (read access to metadata, and read/write access to Actions, variables, and secrets).
   * A **secret** named `AWS_ROLE_TO_ASSUME`. The value should be the ARN of the **role** that was just created when running Terraform apply in the ./requirement folder.
   * A **secret** named `PROVIDER_GITHUB_ARN`. The value should be the ARN of the **provider** that was just created when running Terraform apply in the ./requirement folder.
   * A **variable** named `AWS_REGION`. The value should be the region where you are working (e.g. `us-east-1`).

HPA + Cluster AutoScaler general Explanation:
<img width="4008" height="3028" alt="Scale" src="https://github.com/user-attachments/assets/6343cf36-1836-4526-b41d-0cf7767a6d95" />
