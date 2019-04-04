# k8s-go-vault-training

# BONUS LAB: Onboard your Go K8s App to the Training Vault Service

Duration: 1 hour

You are going to perform the following tasks:

- Task 1: Access your Namespace & Create a Secret
- Task 2: Setup your Secrets Engines
- Task 3: Setup your Auth Methods
- Task 4: Deploy your App
- Task 5: Test your App

## Lab Scenario
This lab is a continuation of all the tasks you've learned in today's session. We are applying these concepts in a common shared service scenario. By the end of this lab you should have a better understanding of how developers, operators, and security groups work together around Vault.  Vault enterprise offers secure multi-tenancy, which we will leverage in our training environment

The application is based on the following sample app: https://github.com/lanceplarsen/go-vault-demo.
It contains a sample microservice written in Go we will deploy to K8s.

Clone the Github assets and let's get started.

`git clone https://github.com/lanceplarsen/go-vault-demo`

## Task 1: Access your Vault Namespace & Create a Secret

Your instructor will provide you with a token to administer your namespace. In a production environment this would likely be tied to your corporate identity (LDAP,OIDC, etc.), but for training person we will hand out some manually created tokens.

### Step 1.1

Login with the either the CLI or UI and check out your namespace. You'll notice your tenant is completely isolated and you cannot interact with your neighbors tenant. You will see the namespace present in the token details.

```
$ vault login -namespace trainer s.PYikHPQHZGOdTJe70EJ2Eu5H.mn7BX
$ vault token lookup -namespace trainer s.PYikHPQHZGOdTJe70EJ2Eu5H.mn7BX | grep namespace_path
namespace_path      trainer/
```

### Step 1.2
Now we can mount a kv

```
vault secrets enable -namespace trainer -path=secret kv
```

Let's write a dummy secret to test our access:

```
$ vault kv put kv/foo bar=baz
Error making API request.

URL: GET http://127.0.0.1:8200/v1/sys/internal/ui/mounts/kv/foo
Code: 403. Errors:

* preflight capability check returned 403, please ensure client's policies grant access to path "kv/foo/"
```

You'll notice this will fail. That is because you are still in the root namespace.  Let's try this again from the namespace you've been assigned.

```
vault kv put -namespace trainer secret/foo bar=baz
Key              Value
---              -----
created_time     2019-04-03T20:53:12.348337949Z
deletion_time    n/a
destroyed        false
version          1
```

```
$ vault kv get -namespace trainer secret/foo
====== Metadata ======
Key              Value
---              -----
created_time     2019-04-03T20:53:12.348337949Z
deletion_time    n/a
destroyed        false
version          1

=== Data ===
Key    Value
---    -----
bar    baz
```

Congrats!!! You've just used your first namespace.

## Task 2: Setup your Secrets Engines

Our Go Application requires a few types of secrets engines to function:
* [Database](https://www.vaultproject.io/docs/secrets/databases/index.html)
* [Transit](https://www.vaultproject.io/docs/secrets/transit/index.html)

A [sample script](https://github.com/lanceplarsen/go-vault-demo/blob/master/scripts/vault.sh) is included to help you enable these engines.

Your trainer will provide you with the endpoints and credentials for your script.

### Step 2.1
The sample script does the below in the following order:
* Ensures the KV Secret Engine is Enabled
* Creates a Least Privilege Policy for our Application
* Ensures the Database Secret Engine is Enabled
* Ensures the Transit Secret Engine is Enabled

We need to update the following entries in the script before we run it:
* [Database URL](https://github.com/lanceplarsen/go-vault-demo/blob/master/scripts/vault.sh#L22)

Your trainer will give you the database endpoint and credentials.

We could rewrite our script to add support for namespaces, but we can also just run the script as is with [environment variable](https://www.vaultproject.io/docs/commands/#vault_namespace)

Let's try it out.

```
$ export VAULT_NAMESPACE=trainer
$ ./vault.sh
Success! Disabled the secrets engine (if it existed) at: secret/
Success! Enabled the kv secrets engine at: secret/
Success! Uploaded policy: order
Success! Enabled the database secrets engine at: database/
WARNING! The following warnings were returned from Vault:

  * Password found in connection_url, use a templated url to enable root
  rotation and prevent read access to password information.

Success! Data written to: database/roles/order
Success! Enabled the transit secrets engine at: transit/
Success! Data written to: transit/keys/order
```

### Step 2.2
At this point we should be able to grab a dynamic secret from the shared database similar to what you did earlier.

```
$ export VAULT_NAMESPACE=trainer
$ vault read database/creds/order
Key                Value
---                -----
lease_id           database/creds/order/GoCdKd5jJYou2vQPfJ8kZhXB.mn7BX
lease_duration     1h
lease_renewable    true
password           A1a-BdtyAoEL2GFU2UPb
username           v-token-order-0TSYz3uFzL7qzQCWUVZU-1554326905
```

With our secrets engines enabled, let's move onto auth methods.

## Task 3:  Setup your Auth Methods

Our Go Application requires the following auth method to function in K8s:
* [Kubernetes](https://www.vaultproject.io/docs/auth/kubernetes.html)

A [sample script](https://github.com/lanceplarsen/go-vault-demo/blob/master/examples/kubernetes/scripts/vault.sh) is included to help you enable this method.

Your trainer will provide you with the endpoints and credentials for your script.

### Step 3.1
The sample script does the below in the following order:
* Ensures the K8s auth method is Enabled
* Creates service accounts in K8s for Vault to use for token reviews
* Establishes trust with the K8s API server.
* Creates a role that links to the K8s service account to the policy we created eariler.

We need to update the following entries in the script before we run it:
* [K8s Host](https://github.com/lanceplarsen/go-vault-demo/blob/master/examples/kubernetes/vault.sh#L18)
* [K8s CA](https://github.com/lanceplarsen/go-vault-demo/blob/master/examples/kubernetes/vault.sh#L19)

The following can be inferred by looking at your K8s config at `~/.kube/config`. If you only have one K8s cluster in your config you could return this for GKE with the follow.
```
$ kubectl config view --raw -o json | jq -r '.clusters[0].cluster."server"' | tr -d '"'
https://35.190.129.114
$ kubectl config view --raw -o json | jq -r '.clusters[0].cluster."certificate-authority-data"' | tr -d '"' | base64 --decode
-----BEGIN CERTIFICATE-----
MIIDCzCCAfOgAwIBAgIQMwTT4VnRtYwnIvIhMuX7LzANBgkqhkiG9w0BAQsFADAv
MS0wKwYDVQQDEyQyYWY3ODk4My04NTE2LTQ2NDAtYmNhMi0wMWE3NzNkYmM1OWEw
HhcNMTkwNDAzMDY0MDQzWhcNMjQwNDAxMDc0MDQzWjAvMS0wKwYDVQQDEyQyYWY3
ODk4My04NTE2LTQ2NDAtYmNhMi0wMWE3NzNkYmM1OWEwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQCwdxjwd4X6HYqddfXmy6ec3jUffGEhiqL32Fn9qC8+
NGgJpO2f9RirB6t1lNCmkpCXSQBa1dxI4xPcYwPbMvx3sfZ7WQS2reBlHpADPloV
sF4saN9jvF5Za3lCCzm8U0lzLYF91AMoyqN9UMpuNvHNcsFYtZYpXbpg4hvfXa46
p0RiKlYDb4Hf6DjYIy+Mpc7pqd7YjzOAkCNqreOsRS0IWFV5VScu8Aa19DrUVvAZ
v7mxHi/hKmT3BtHx+9I1sOvyRjSKXOOiq08Z7H+H3+A0HflcKrYHLPFJ3O5bNXjP
uXq/Lh21HjUUsc6JcVeNjtziKU3LNSDEdQKuXIJkQ0ptAgMBAAGjIzAhMA4GA1Ud
DwEB/wQEAwICBDAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQBJ
AwSMsGebyvWp1b+VHKu99APPDPUhc1dxe7pFpEhMh8+TUg416hESdzJ1ro3hoLm3
Sf9dxTWUdAsCyD2vkZs9FEVfkWL9gWYpbrIlYrN8PZ7icX5yF1rxURnHl7kEcd82
ymwhs3acRhHXHY6w+lSOPIuqJwKFmSOcto9iAwNccOizD0fDVd3uN97DTayNDg1x
u9mvpuY24X5wk1to2hcqrxVY1Ao6S7YkmCSKQBE2PLZFcIwnnQZ8pFLImewK6YrE
1N3RNdHeyXmgLutzTaZC1LZE07nuaN+Cf/ZZ1LcCVxy0zzNMLC/5b+tqj6TJBHB/
wvCoxllROZI6ykRfvOpK
-----END CERTIFICATE-----
```

If you are having trouble with this step as your instructor for help.

Now run your script
```
$ export VAULT_NAMESPACE=trainer
$ ./vault.sh
Success! Enabled kubernetes auth method at: kubernetes/
serviceaccount/vault created
clusterrolebinding.rbac.authorization.k8s.io/vault created
Success! Data written to: auth/kubernetes/config
Success! Data written to: auth/kubernetes/role/order
serviceaccount/go created
```

### Step 3.3
Let's grab a K8s service Account token we created for the Go App and use it to login with Vault.

```
$kubectl --namespace=default get serviceaccounts go -o json | jq -r .secrets[0].name
go-token-6l45j

$ kubectl --namespace=default  get secret go-token-6l45j  -o json | jq -r .data.token | base64 --decode
eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6ImdvLXRva2VuLTZsNDVqIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImdvIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiMTFhODFkMjgtNTY2Yy0xMWU5LTgzYjItNDIwMTBhOGUwMDQyIiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OmRlZmF1bHQ6Z28ifQ.Fex0Dxbv85FePIbcY8KAbgAsGWVIlyvuVIOxr9qKtAa1YTFPhyCNy-Em5xofKqud_hIt13rZqGvC_uMiT2TJ_0PLh851xkphLFZdto3wx0BidQd160YIywbKdKuZtPfoUu6KlAsHwHSUug0Cf70GHwYes8-4jCcL0DStVhPyudkxkXg0B2Z0BvMUSe6A2YaVxN5QbXJta19vsKjTMiasbwm9Jv4DhZTyqjK4H5ACw9t0lrop54VZGvy5o3gtzRX3wsB7BGGJtKMJuWm6K5n0cXt8ncBHZ8avQsfL_pBGFWP461g66V5MDNA6mmdMKixZTj6k_WAuaQBIqxgk0VrgpA

$ vault write auth/kubernetes/login role=order jwt=eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6ImdvLXRva2VuLTZsNDVqIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImdvIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiMTFhODFkMjgtNTY2Yy0xMWU5LTgzYjItNDIwMTBhOGUwMDQyIiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OmRlZmF1bHQ6Z28ifQ.Fex0Dxbv85FePIbcY8KAbgAsGWVIlyvuVIOxr9qKtAa1YTFPhyCNy-Em5xofKqud_hIt13rZqGvC_uMiT2TJ_0PLh851xkphLFZdto3wx0BidQd160YIywbKdKuZtPfoUu6KlAsHwHSUug0Cf70GHwYes8-4jCcL0DStVhPyudkxkXg0B2Z0BvMUSe6A2YaVxN5QbXJta19vsKjTMiasbwm9Jv4DhZTyqjK4H5ACw9t0lrop54VZGvy5o3gtzRX3wsB7BGGJtKMJuWm6K5n0cXt8ncBHZ8avQsfL_pBGFWP461g66V5MDNA6mmdMKixZTj6k_WAuaQBIqxgk0VrgpA
Key                                       Value
---                                       -----
token                                     s.wmoFNDAnqnVHQNtf68jriVMa.mn7BX
token_accessor                            w5JhZYZiLYr3FfCpqFPzl645.mn7BX
token_duration                            30m
token_renewable                           true
token_policies                            ["default" "order"]
identity_policies                         []
policies                                  ["default" "order"]
token_meta_role                           order
token_meta_service_account_name           go
token_meta_service_account_namespace      default
token_meta_service_account_secret_name    go-token-6l45j
token_meta_service_account_uid            11a81d28-566c-11e9-83b2-42010a8e0042


```

Now that we've established trust between Vault and K8s. Let's try this in our Go application.

## Task 4: Deploy your App
The [Kubernetes examples](https://github.com/lanceplarsen/go-vault-demo/tree/master/examples/kubernetes) has the deployment files for our application.

### Step 4.1

We need to change a few files in the configuration for our environment.
* [Change the Database Host](https://github.com/lanceplarsen/go-vault-demo/blob/master/examples/kubernetes/go-config.yaml#L8)
* [Change the Vault Host](https://github.com/lanceplarsen/go-vault-demo/blob/master/examples/kubernetes/go-config.yaml#L12)
* Add a namespace

### Step 4.2

With our config updated, let's deploy the app. You should see a similar output.

```
$ kubectl apply -f go-config.yaml
configmap/go created

$ kubectl apply -f go-pod.yaml
pod/go created

$ kubectl apply -f go-service.yaml
service/go created

$ kubectl get pod go
NAME   READY   STATUS    RESTARTS   AGE
go     1/1     Running   0          16s

$ kubectl logs go
2019/04/04 01:25:06 Starting server initialization
2019/04/04 01:25:06 Starting vault initialization
2019/04/04 01:25:06 Namespace: trainer
2019/04/04 01:25:06 Client authenticating to Vault
2019/04/04 01:25:06 Using kubernetes authentication
2019/04/04 01:25:06 Mount: auth/kubernetes
2019/04/04 01:25:06 Role: order
2019/04/04 01:25:06 SA: /var/run/secrets/kubernetes.io/serviceaccount/token
2019/04/04 01:25:06 Metadata: map[role:order service_account_name:go service_account_namespace:default service_account_secret_name:go-token-ml7kb service_account_uid:ca7dd121-566d-11e9-83b2-42010a8e0042]
2019/04/04 01:25:06 Looking up token
2019/04/04 01:25:06 Starting DB initialization
2019/04/04 01:25:06 DB role: order
2019/04/04 01:25:06 Getting secret: database/creds/order
2019/04/04 01:25:06 Starting token lifecycle management for accessor: olWe6LI8tPEmMKWiv0OMi1o8.mn7BX
2019/04/04 01:25:06 Starting secret lifecycle management for lease: database/creds/order/znhbBmIP6oeLHcT9YrWFM5h0.mn7BX
2019/04/04 01:25:06 Successfully renewed token accessor: olWe6LI8tPEmMKWiv0OMi1o8.mn7BX
2019/04/04 01:25:06 Successfully renewed secret lease: database/creds/order/znhbBmIP6oeLHcT9YrWFM5h0.mn7BX
2019/04/04 01:25:07 Getting certificate: pki/issue/order
2019/04/04 01:25:12 Server is now accepting http requests on port 3000
2019/04/04 01:25:12 Server is now accepting https requests on port 8443
```

Congrats!!! Your app is now running on K8s and accepting traffic.

## Task 5: Test our application

Now that our application is running. We can test a few of its APIs.

### Step 5.1

First, let's grab our endpoint from the GKE cluster

```
$ kubectl get services go
NAME   TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)          AGE
go     LoadBalancer   10.55.249.41   34.73.124.99   3000:31285/TCP   1m
```

### Step 5.2

Now that we have an endpoint, let's check a few of the APIs.
* Health
* Add Order
* Get Orders

```
$ curl -s 34.73.124.99:3000/health | jq
{
  "Postgres": {
    "status": "UP",
    "version": "PostgreSQL 9.6.3 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.3 20140911 (Red Hat 4.8.3-9), 64-bit"
  },
  "Vault": {
    "code": 200,
    "status": "UP"
  },
  "status": "UP"
}

curl -s -X POST   http://34.73.124.99:3000/api/orders   -d '{"customerName": "lance", "productName": "Vault Enterprise"}' | jq
{
  "id": 1,
  "customerName": "lance",
  "productName": "Vault Enterprise",
  "orderDate": "2019-04-04T01:46:13.02065613Z"
}

$ curl -s http://34.73.124.99:3000/api/orders | jq
{
  "orders": [
    {
      "id": 1,
      "customerName": "lance",
      "productName": "Vault Enterprise",
      "orderDate": "2019-04-04T01:46:13.02065613Z"
    }
  ]
}
```

## Additional Exercises


### End of Bonus Lab
