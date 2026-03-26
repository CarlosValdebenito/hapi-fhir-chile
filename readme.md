# HAPI FHIR Server - Localización Chile (CL Core)

Este proyecto despliega un servidor HAPI FHIR optimizado para la Guía de Implementación (IG) de Chile. Para maximizar la estabilidad, utilizamos un enfoque de **Infraestructura Limpia + Inyección de Datos**.

---

## 🏗️ 1. Construcción de la Imagen
Compilamos el servidor usando **Java 21**. Esta versión es ligera y no incluye la descarga automática de la IG para evitar fallos críticos en el arranque (Error 502).

```bash
docker build -t hapi-chile .
```

---

## 🚀 2. Despliegue del Contenedor
Ejecutamos el motor FHIR. Hemos configurado una base de datos en memoria y límites de RAM para asegurar que funcione en entornos de recursos limitados como Killercoda.

```bash
docker run -d -p 8080:8080 --name hapi-test \
  -e "spring.datasource.url=jdbc:h2:mem:testdb" \
  -e "hapi.fhir.allow_external_references=true" \
  -e "JAVA_OPTS=-Xmx1024m" \
  hapi-chile
```

> **Validación:** Verifica que el servidor responda en `http://localhost:8080` antes de pasar al siguiente paso.

---

## 🇨🇱 3. Carga de la Guía de Chile (CL Core)
Una vez que el motor está "Up", inyectamos los recursos de la IG Core-CL. Este método permite identificar errores específicos en archivos JSON sin que el servidor se caiga.

### Ejecución desde la terminal (Bash)
Asegúrate de tener los archivos JSON en una carpeta llamada `/package` y ejecuta este loop:

```bash
for f in ./package/*.json; do
  # Extraemos Tipo e ID del recurso usando jq
  RES_TYPE=$(jq -r '.resourceType' "$f")
  RES_ID=$(jq -r '.id' "$f")
  
  echo "Cargando: $RES_TYPE/$RES_ID"
  
  # Inyección vía API REST (PUT)
  curl -X PUT "http://localhost:8080/fhir/$RES_TYPE/$RES_ID" \
       -H "Content-Type: application/json" \
       --data-binary @"$f"
done
```

