# Historia Reader Platform

Plataforma de lectura de libros de historia estilo Netflix, construida como proyecto de portfolio para Cloud Engineer. Subís un PDF y queda disponible de forma automática para usuarios autenticados a través de un pipeline serverless seguro.

---

## Arquitectura

![Arquitectura AWS](architecture.png)

```
S3 Upload → EventBridge → Step Functions → DynamoDB
                                              ↓
Usuario → Cognito → API Gateway → Lambda → CloudFront Signed URL → PDF
```

**8 módulos de Terraform:**

| Módulo | Recursos |
|--------|----------|
| `storage` | Buckets S3 (libros + frontend) |
| `cdn` | Distribución CloudFront, OAC, RSA key group |
| `auth` | Cognito User Pool + Client |
| `database` | Tablas DynamoDB (libros + progreso de lectura) |
| `api` | API Gateway HTTP, Lambda backend, Secrets Manager |
| `ingestion` | Step Functions, pipeline de 4 Lambdas, EventBridge |
| `observability` | Dashboards y alarmas CloudWatch, SNS |
| `cicd` | IAM OIDC role para GitHub Actions |

---

## Funcionalidades

- **Pipeline de ingesta automático** — subís un PDF a S3, EventBridge lo detecta y Step Functions ejecuta validación, extracción de metadatos, generación de thumbnail y registro en catálogo de forma automática
- **Entrega segura de PDFs** — CloudFront Signed URLs con par de claves RSA; los PDFs nunca son públicamente accesibles
- **Autenticación JWT** — Cognito emite tokens, API Gateway los valida en cada request
- **Infraestructura como Código** — Terraform completamente modularizado con estado remoto en S3
- **CI/CD** — GitHub Actions con OIDC (sin credenciales AWS de larga duración)
- **Observabilidad** — Dashboard CloudWatch con métricas de ejecuciones del pipeline, errores y duración de Lambda

---

## Pipeline de Ingesta

```
PDF subido a S3
      ↓
EventBridge (Object Created)
      ↓
Step Functions
      ├── Validation        → verifica que el archivo sea un PDF válido
      ├── MetadataExtractor → extrae título, autor y cantidad de páginas
      ├── ThumbnailGenerator → genera imagen de portada (Pillow via Klayers)
      └── CatalogRegister   → escribe el registro del libro en DynamoDB
```

---

## Endpoints de la API

Todos los endpoints requieren el header `Authorization: Bearer <id_token>`.

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/books` | Lista todos los libros (soporta filtro `?genre=`) |
| GET | `/books/{book_id}` | Obtiene metadatos de un libro |
| GET | `/books/{book_id}/url` | Obtiene Signed URL de CloudFront para el PDF |
| PUT | `/books/{book_id}/progress` | Guarda el progreso de lectura |

---

## Stack tecnológico

- **IaC:** Terraform 1.x (modularizado, backend en S3)
- **Cloud:** AWS (S3, CloudFront, Lambda, API Gateway HTTP, DynamoDB, Cognito, Step Functions, EventBridge, Secrets Manager, SNS, CloudWatch, IAM)
- **Runtime:** Python 3.12
- **CI/CD:** GitHub Actions + OIDC
- **Frontend:** HTML/CSS/JS vanilla + Amazon Cognito Identity SDK

---

## Decisiones de diseño clave

**CloudFront Signed URLs en lugar de S3 presigned URLs** — CloudFront está por delante de S3, los PDFs nunca quedan expuestos directamente. La Lambda firma las URLs con una clave privada RSA guardada en Secrets Manager; CloudFront valida contra la clave pública registrada en un Key Group.

**EventBridge en lugar de S3 Event Notifications** — desacopla la capa de almacenamiento del procesamiento. Agregar nuevos pasos al pipeline no requiere cambios en la configuración del bucket S3.

**OIDC para CI/CD** — GitHub Actions asume un IAM Role vía federación OIDC. No se almacenan access keys de AWS como secrets de GitHub.

**`recovery_window_in_days = 0` en Secrets Manager** — evita el período de gracia de 7 días al destruir y redesployar el stack.

---

## Deploy

### Prerequisitos
- AWS CLI configurado
- Terraform instalado
- Repositorio en GitHub con Actions habilitado

### Primer deploy

```bash
# Bootstrap del estado remoto
cd terraform/bootstrap
terraform init && terraform apply

# Crear el OIDC provider (una sola vez por cuenta AWS)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Deployar el módulo cicd localmente (GitHub Actions necesita el role primero)
cd ../terraform
terraform init
terraform apply -target=module.cicd

# Push a main — GitHub Actions despliega el resto
git push origin main
```

### Post-deploy

```bash
# Subir la clave privada a Secrets Manager
aws secretsmanager put-secret-value \
  --secret-id historia-reader-cf-private-key-dev \
  --secret-string file:///ruta/a/private_key.pem

# Subir un libro
aws s3 cp mi-libro.pdf s3://historia-reader-books-dev/books/mi-libro.pdf

# Ver outputs de Terraform
terraform output
```

### Teardown

```bash
aws s3 rm s3://historia-reader-books-dev --recursive
aws s3 rm s3://historia-reader-frontend-dev --recursive
terraform destroy
```

---

## Estructura del proyecto

```
historia-reader/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── providers.tf
│   ├── backend.tf
│   └── modules/
│       ├── storage/
│       ├── cdn/
│       ├── auth/
│       ├── database/
│       ├── api/
│       ├── ingestion/
│       ├── observability/
│       └── cicd/
├── lambdas/
│   ├── backend/
│   ├── validation/
│   ├── metadata_extractor/
│   ├── thumbnail_generator/
│   └── catalog_register/
└── frontend/
    └── index.html
```

---

## Autor

Santiago Albi — [GitHub](https://github.com/SantiagoAlbi) · [LinkedIn](https://www.linkedin.com/in/santiagoalbisetti/)
