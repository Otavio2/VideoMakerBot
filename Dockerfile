# Imagem oficial do Dart
FROM dart:stable

# Define o diretório de trabalho
WORKDIR /app

# Copia todos os arquivos do projeto
COPY . .

# Resolve dependências do Dart
RUN dart pub get

# Exponha a porta que o bot usará
EXPOSE 8080

# Comando para iniciar o bot
CMD ["dart", "run", "main.dart"]
