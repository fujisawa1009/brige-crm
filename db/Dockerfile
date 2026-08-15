# 開発用 PostgreSQL イメージ。全文検索（Phase 8）で使う pg_bigm 拡張を同梱する。
# alpine は musl で C 拡張のビルドが面倒なため Debian 系の公式 postgres イメージをベースにする。
# 本番（AWS RDS / Aurora）では pg_bigm は標準サポート拡張のため、このカスタムイメージは開発用のみ。
FROM postgres:16

# pg_bigm リリース: https://github.com/pgbigm/pg_bigm/releases
ARG PG_BIGM_VERSION=1.2-20240606

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        postgresql-server-dev-16 \
        libicu-dev \
        curl \
        ca-certificates; \
    curl -fsSL -o /tmp/pg_bigm.tar.gz \
        "https://github.com/pgbigm/pg_bigm/archive/refs/tags/v${PG_BIGM_VERSION}.tar.gz"; \
    tar zxf /tmp/pg_bigm.tar.gz -C /tmp; \
    cd "/tmp/pg_bigm-${PG_BIGM_VERSION}"; \
    make USE_PGXS=1; \
    make USE_PGXS=1 install; \
    apt-get purge -y --auto-remove build-essential postgresql-server-dev-16 libicu-dev curl; \
    rm -rf /var/lib/apt/lists/* /tmp/pg_bigm*

# pg_bigm は shared_preload_libraries への追加は不要（preload 不要）。
# 拡張の有効化は Rails マイグレーション（enable_extension "pg_bigm"）で行う。
