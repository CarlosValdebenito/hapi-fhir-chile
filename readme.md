# HAPI FHIR Server - Localización Chile (CL Core)

Este repositorio contiene la configuración para desplegar un servidor **HAPI FHIR** basado en **Java 21**, optimizado para la **Guía de Implementación Core-CL**.

## 🚀 Guía de Despliegue Rápido

Siga estos pasos en orden cronológico para levantar el servidor e inyectar los perfiles de Chile.

### 1. Preparación del Entorno
Clone el repositorio y prepare la carpeta donde residirán los recursos de la IG.

```bash
git clone https://github.com/CarlosValdebenito/hapi-fhir-chile
```

```bash
cd hapi-fhir-chile
```

2. Descarga de la IG Chile (CL Core)Descargamos y descomprimimos la versión 1.9.3 de la Guía de Implementación manualmente para asegurar la integridad de los archivos.

**Descargar paquete oficial**
```bash
curl -L https://hl7chile.cl/fhir/ig/clcore/package.tgz -o package.tgz
```

```bash
tar -xvzf package.tgz
```

```bash
rm package.tgz
```

3. Construcción y Lanzamiento (Docker)Construimos la imagen limpia (sin dependencias externas de red al arrancar) para evitar errores 502.

**Construir imagen**
```bash
docker build -t hapi-chile .
```

**Lanzar contenedor con base de datos H2 en memoria**
```bash
docker run -d -p 8080:8080 --name hapi-test \
  -e "spring.datasource.url=jdbc:h2:mem:testdb" \
  -e "hapi.fhir.allow_external_references=true" \
  -e "JAVA_OPTS=-Xmx1024m" \
  hapi-chile
```

Nota: Espere aproximadamente 2-3 minutos a que el servidor inicialice. 

**Puede monitorear el progreso con **
```bash
docker logs -f hapi-test
```

4. Inyección Masiva de Recursos (Script de Carga)Una vez que el servidor responda en el puerto 8080, ejecute este script para cargar los perfiles, ValueSets y CodeSystems de Chile mediante la API REST.Bash

**Instalar jq para procesar los IDs de los recursos**
```bash
sudo apt update && sudo apt install jq -y
```

**Ejecutar carga masiva vía PUT**
```bash
for f in ./package/*.json; do
  # Extraer Tipo e ID
  T=$(jq -r '.resourceType' "$f")
  I=$(jq -r '.id' "$f")
  
  if [ "$T" != "null" ] && [ "$I" != "null" ]; then
    # Ejecutar carga y capturar solo el código HTTP (200, 201, 400, etc)
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "http://localhost:8080/fhir/$T/$I" \
         -H "Content-Type: application/json" \
         --data-binary @"$f")
    
    # Mostrar resultado simple en una línea
    if [[ "$STATUS" =~ ^2 ]]; then
      echo "[ OK $STATUS ] Cargado: $T/$I"
    else
      echo "[ ERROR $STATUS ] Falló: $T/$I"
    fi
    
    # Pausa para que el servidor no colapse
    sleep 2
  fi
done
```

🛠️ Solución de Problemas (Troubleshooting)ProblemaCausa ProbableSoluciónError 502 Bad Gateway
El servidor aún está arrancando o se quedó sin RAM.
Revisar docker logs hapi-test. Esperar 2 min.Contenedor detenido
Error en el JpaPackageCache o falta de memoria.
Asegurarse de NO incluir la descarga de la IG en el Dockerfile.
Error 400 en el ScriptRecurso JSON mal formado o falta de dependencias.
El script continuará con el siguiente recurso. Revisar el ID fallido.
