# GastroSENA — Guía de despliegue con Docker

Este repositorio levanta el sistema completo de GastroSENA: frontend, 5 microservicios backend, 5 bases de datos MySQL, RabbitMQ y Zipkin.

**No necesitás tener ningún código fuente.** Todo se descarga automáticamente desde Docker Hub.

---

## Requisitos previos

| Herramienta | Versión mínima | Descarga |
|---|---|---|
| Docker Desktop | 4.x | https://www.docker.com/products/docker-desktop |
| Docker Compose | incluido en Docker Desktop | — |

> **Importante:** Docker Desktop debe estar corriendo antes de ejecutar cualquier comando.

---

## Estructura de lo que se levanta

```
GastroSENA
├── Frontend (Angular + nginx)        → puerto 4200
│
├── Microservicios Backend
│   ├── Restaurante (Spring Boot)     → puerto 8080
│   ├── Inventario  (Spring Boot)     → puerto 8081
│   ├── Cocina      (Spring Boot)     → puerto 8082
│   ├── Barbarismo  (Spring Boot)     → puerto 8086
│   └── Usuarios    (Spring Boot)     → puerto 8087
│
├── Bases de datos (MySQL 8.0)
│   ├── restaurante-db                → puerto 3308
│   ├── inventario-db                 → puerto 3307
│   ├── cocina-db                     → puerto 3309
│   ├── barbarismo-db                 → puerto 3310
│   └── usuarios-db                   → puerto 3311
│
├── RabbitMQ (mensajería)             → puerto 5672
│   └── Panel de administración       → puerto 15672
│
└── Zipkin (trazabilidad)             → puerto 9411
```

---

## Imágenes de Docker Hub

| Servicio | Imagen |
|---|---|
| Frontend | `stiven77/frontend-gastrosena:latest` |
| Restaurante | `eidertapasco/ga-ms-restaurante:latest` |
| Inventario | `stiven77/ga-ms-inventario:latest` |
| Cocina | `andres2515/ga-ms-cocina:latest` |
| Barbarismo | `jhojanalvarez71/ga-ms-barbarismo:latest` |
| Usuarios | `sofigarcia30/ga-ms-usuarios:latest` |

---

## Cómo levantar el sistema

### 1. Abrí una terminal en esta carpeta

**Windows:** clic derecho sobre la carpeta `GastrosenaDocker` → "Abrir en Terminal"  
**Mac/Linux:** `cd /ruta/a/GastrosenaDocker`

### 2. Ejecutá el siguiente comando

```bash
docker compose up -d
```

La primera vez tarda varios minutos porque descarga todas las imágenes. Las siguientes veces es mucho más rápido.

### 3. Esperá a que todo esté listo

Vas a ver logs de cada servicio. El sistema está listo cuando dejes de ver errores de conexión y los backends digan que iniciaron correctamente.

> Las bases de datos tardan ~30 segundos en estar disponibles. Los backends tienen reintentos automáticos, así que si ves algún error de conexión al inicio, es normal — se recuperan solos.

### 4. Abrí la aplicación

Entrá a tu navegador y abrí:

```
http://localhost:4200
```

---

## Puertos disponibles en tu PC

| URL | Qué es |
|---|---|
| http://localhost:4200 | **Aplicación principal** (entrá acá) |
| http://localhost:8080 | API Restaurante (pedidos, mesas, caja) |
| http://localhost:8081 | API Inventario |
| http://localhost:8082 | API Cocina |
| http://localhost:8086 | API Barbarismo (bar) |
| http://localhost:8087 | API Usuarios / Autenticación |
| http://localhost:15672 | Panel RabbitMQ (usuario: `guest`, contraseña: `guest`) |
| http://localhost:9411 | Panel Zipkin (trazabilidad de requests) |

### Conexión directa a las bases de datos

Si necesitás inspeccionar los datos con DBeaver, TablePlus o similar:

| Base de datos | Host | Puerto | Usuario | Contraseña |
|---|---|---|---|---|
| Restaurante | localhost | 3308 | root | root |
| Inventario | localhost | 3307 | inventario | inventario |
| Cocina | localhost | 3309 | root | Carlos2515. |
| Barbarismo | localhost | 3310 | root | admin1 |
| Usuarios | localhost | 3311 | usuario_app | clave_segura |

---

## Cómo detener el sistema

```bash
docker compose down
```

Esto detiene y elimina los contenedores pero **los datos de las bases de datos se conservan** (están en volúmenes de Docker).

Si querés borrar también los datos y empezar desde cero:

```bash
docker compose down -v
```

> ⚠️ El flag `-v` elimina los volúmenes. Todos los datos guardados en las bases de datos se pierden.

---

## Solución de problemas frecuentes

### "Puerto X ya está en uso"

Algún programa en tu PC ya usa ese puerto. Opciones:
- Cerrá el programa que lo usa (MySQL local, otro servidor, etc.)
- O editá el `docker-compose.yml` y cambiá el puerto del host (la parte **izquierda** del `:`).  
  Ejemplo: cambiar `"3307:3306"` por `"3312:3306"`.

### Un backend no arranca / sigue reiniciando

Es normal los primeros 30-60 segundos mientras la base de datos termina de iniciar. Si después de 2 minutos sigue fallando, revisá los logs:

```bash
docker compose logs nombre-del-servicio
```

Por ejemplo:
```bash
docker compose logs inventario
docker compose logs restaurante
```

### Quiero ver los logs de todo en tiempo real

```bash
docker compose logs -f
```

### Quiero reiniciar solo un servicio

```bash
docker compose restart nombre-del-servicio
```

---

## Reconstruir imágenes desde fuente (mantenedores)

> Esta sección es solo para quien modifica un microservicio y necesita regenerar su imagen.
> Para *usar* el sistema no hace falta nada de esto: las imágenes se bajan de Docker Hub.

### ⚠️ Java 21 obligatorio (gotcha de Lombok con JDK 25)

El estándar del equipo es **Java 21**. Si tu máquina tiene **JDK 25** como `java`/`JAVA_HOME`
por defecto, el build local **falla** con errores tipo `cannot find symbol setXxx(...)`:
Lombok (1.18.38) **no soporta JDK 25** y no genera los setters/getters.

Dos formas de evitarlo:

1. **Instalá Temurin 21** y apuntá `JAVA_HOME` a él antes de compilar:
   ```bash
   java -version   # debe decir 21.x
   ```
2. **O compilá dentro de un contenedor con JDK 21** (independiente de tu entorno).
   Útil cuando el Dockerfile espera el `.jar` ya construido (ej. reportes):
   ```bash
   docker run --rm \
     -v "$PWD":/app -v "$HOME/.m2":/root/.m2 -w /app \
     maven:3.9.6-eclipse-temurin-21 mvn -B -DskipTests package
   ```

### Cocina: inicializar el submódulo antes del build

`ga-ms-cocina` trae `ga-lib-security` como **submódulo git**. Si está sin inicializar,
el `docker build` falla con `Non-readable POM .../ga-lib-security/pom.xml`:

```bash
cd ga-ms-cocina
git submodule update --init --recursive
docker build -t andres2515/ga-ms-cocina:latest .
```

### Probar una imagen recién construida sin publicarla

Si la buildeás con el **mismo tag** del compose y recreás **sin pull**, Docker usa tu
imagen local (no va a Docker Hub):

```bash
docker compose up -d --no-deps --force-recreate cocina
```

### Regla del secreto JWT (`SECURITY_SECRET`)

- Lo definen **solo** `usuarios` (firma), `gateway` (valida) y `cocina`, **siempre vía
  `${SECURITY_SECRET}` desde `.env`** — nunca hardcodeado.
- `cocina` lo necesita al arrancar porque su `ga-lib-security` pinneado construye
  `JwtConfig` de forma incondicional, aunque en runtime autentique por headers.
- El resto (`restaurante`, `inventario`, `barbarismo`, `reportes`) es **gateway-trust**
  y **no** define el secreto.
- Para verificar que está alineado:
  ```bash
  docker compose exec cocina   printenv SECURITY_SECRET
  docker compose exec usuarios printenv SECURITY_SECRET
  docker compose exec gateway  printenv SECURITY_SECRET
  ```
  Los tres deben imprimir el mismo valor; si no, el login falla con 401.

---

## Requisitos de hardware recomendados

| Recurso | Mínimo |
|---|---|
| RAM | 8 GB (el sistema usa ~4-5 GB en total) |
| Disco | 5 GB libres para imágenes y datos |
| CPU | 4 núcleos recomendados |

---

## Arquitectura resumida

El frontend es una aplicación Angular servida por nginx. nginx también actúa como **reverse proxy**: cuando el frontend hace llamadas a la API, nginx las redirige al microservicio correcto según el path:

| Path | Microservicio |
|---|---|
| `/api/v1/*` | Inventario |
| `/api/barybarismo`, `/api/alertas` | Barbarismo |
| `/api/cocina`, `/api/actividades`, `/api/recetas`, `/api/ingredientes`, `/api/categorias`, `/api/pasos` | Cocina |
| `/api/pedidos`, `/api/mesas`, `/api/caja`, `/sesion`, `/facturar`, `/facturas` | Restaurante |
| `/auth`, `/api/*` (resto) | Usuarios |

Todos los contenedores están en la misma red interna (`gastrosena-net`) y se comunican entre sí por nombre de contenedor.
