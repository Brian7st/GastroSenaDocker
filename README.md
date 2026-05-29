# GastroSENA — Guía de despliegue con Docker

Este repositorio levanta el sistema completo de GastroSENA: frontend, 5 microservicios backend, 5 bases de datos MySQL, RabbitMQ y Zipkin.

> **Nota:** el frontend se construye localmente desde el código fuente. Los microservicios backend se descargan automáticamente desde Docker Hub.

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
| Frontend | construida localmente desde `Dockerfile` |
| Restaurante | `eidertapasco/ga-ms-restaurante:latest` |
| Inventario | `stiven77/ga-ms-inventario:latest` |
| Cocina | `andres2515/ga-ms-cocina:latest` |
| Barbarismo | `jhojanalvarez71/ga-ms-barbarismo:3.0` |
| Usuarios | `sofigarcia30/ga-ms-usuarios:latest` |

---

## Cómo levantar el sistema

### 1. Compilá el frontend

Antes de construir la imagen, necesitás generar el build de producción de Angular. Desde la raíz del proyecto del frontend:

```bash
npx nx build restaurant-app --configuration=production
```

Esto genera el output en `dist/apps/restaurant-app/browser/`.

### 2. Copiá el build a esta carpeta

Copiá la carpeta `dist/` generada a la raíz de este repositorio (`GastrosenaDocker/`), de modo que quede así:

```
GastrosenaDocker/
├── dist/
│   └── apps/
│       └── restaurant-app/
│           └── browser/
├── Dockerfile
├── nginx.conf
└── docker-compose.yml
```

### 3. Abrí una terminal en esta carpeta

**Windows:** clic derecho sobre la carpeta `GastrosenaDocker` → "Abrir en Terminal"  
**Mac/Linux:** `cd /ruta/a/GastrosenaDocker`

### 4. Ejecutá el siguiente comando

```bash
docker compose up --build
```

El flag `--build` le indica a Docker que construya la imagen del frontend antes de levantar los contenedores. Las siguientes veces solo es necesario si cambia el frontend; de lo contrario podés usar:

```bash
docker compose up -d
```

### 6. Esperá a que todo esté listo

Vas a ver logs de cada servicio. El sistema está listo cuando dejes de ver errores de conexión y los backends digan que iniciaron correctamente.

> Las bases de datos tardan ~30 segundos en estar disponibles. Los backends tienen reintentos automáticos, así que si ves algún error de conexión al inicio, es normal — se recuperan solos.

### 7. Abrí la aplicación

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
