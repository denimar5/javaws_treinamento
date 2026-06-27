# Imagem de runtime do Java 21 (JRE basta para rodar; JDK so e preciso para compilar)
FROM eclipse-temurin:21-jre

WORKDIR /app

# Nome real do jar gerado pelo Maven: hello-0.0.1-SNAPSHOT.jar
# (confirme sempre com: ls target/*.jar)
COPY target/hello-0.0.1-SNAPSHOT.jar app.jar

EXPOSE 8080

# -Xms/-Xmx definem memoria minima e maxima da JVM
ENTRYPOINT ["java", "-Xms512m", "-Xmx1536m", "-jar", "app.jar"]
