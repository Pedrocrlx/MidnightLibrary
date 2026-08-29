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


FROM builder AS development

ENV PATH="/app/.venv/bin:$PATH"

RUN poetry install \
    --with dev \
    --no-root \
    --no-ansi

COPY . .

EXPOSE 8000

CMD ["python", "django-app/manage.py", "runserver", "0.0.0.0:8000"]


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

# A new named volume inherits this directory's ownership. Existing production
# volumes require the one-time ownership repair documented in the deployment.
RUN mkdir -p /app/django-app/staticfiles \
    && chown -R django:django /app/django-app/staticfiles

USER django

EXPOSE 8000

CMD ["uvicorn", "--app-dir", "/app/django-app", "--host", "0.0.0.0", "--port", "8000", "LMS.asgi:application"]
