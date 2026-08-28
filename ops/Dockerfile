# syntax=docker/dockerfile:1

FROM python:3.12-slim AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1

WORKDIR /app

RUN pip install --no-cache-dir poetry

COPY pyproject.toml poetry.lock ./

RUN poetry install \
    --only main \
    --no-root \
    --no-ansi


FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:$PATH"

WORKDIR /app

RUN addgroup --system django \
    && adduser --system --ingroup django django

COPY --from=builder /app/.venv /app/.venv
COPY --chown=django:django django-app/ /app/django-app/
COPY --chown=django:django books.json /app/books.json

USER django

EXPOSE 8000

CMD ["uvicorn", "--app-dir", "/app/django-app", "--host", "0.0.0.0", "--port", "8000", "LMS.asgi:application"]