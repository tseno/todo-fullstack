# ===== ビルドステージ: Gradleでアプリケーションをビルドする =====
FROM eclipse-temurin:25-jdk AS build
WORKDIR /workspace

# 依存関係のダウンロードをキャッシュしやすくするため、まずビルド定義だけをコピーする
COPY gradlew gradlew
COPY gradle gradle
COPY build.gradle.kts settings.gradle.kts ./
COPY src src

RUN ./gradlew bootJar --no-daemon

# ===== 実行ステージ: JREだけの軽量イメージで起動する =====
FROM eclipse-temurin:25-jre
WORKDIR /app

COPY --from=build /workspace/build/libs/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
