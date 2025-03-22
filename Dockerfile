# 1. Imagen base ligera con Python 3.12
FROM python:3.12-slim

# 2. Copiar el ejecutable de uv desde su imagen oficial precompilada
COPY --from=ghcr.io/astral-sh/uv:0.6.8 /uv /uvx /bin/

# 3. Crear usuario seguro, instalar herramientas necesarias y limpiar
RUN mkdir /src \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        unzip curl gcc build-essential python3-dev libffi-dev liblz4-dev \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r streamlitGroup \
    && useradd -r -m -g streamlitGroup streamlitUser

# 4. Definir el directorio de trabajo dentro del contenedor
WORKDIR /src

# 5. Instalar dependencias desde pyproject.toml y uv.lock SIN copiar el código todavía
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --no-install-project --no-dev

# 6. Copiar el resto del proyecto
ADD pyproject.toml uv.lock /src/
ADD ./src /src/src
ADD .streamlit /src/.streamlit

# 7. Reinstalar dependencias si hace falta (tras añadir código)
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

# 8. Asegurar permisos para el usuario no-root
RUN chmod +x -R /src && chown -R streamlitUser:streamlitGroup /src

# 9. Cambiar al usuario seguro
USER streamlitUser

# 10. Healthcheck opcional para producción
HEALTHCHECK CMD curl --fail http://localhost:8501/_stcore/health || exit 1

# 11. Comando por defecto: ejecutar la app Streamlit usando uv
ENTRYPOINT ["uv", "run", "streamlit", "run", "src/app/frontend/app.py", "--server.port=8501", "--server.address=0.0.0.0"]