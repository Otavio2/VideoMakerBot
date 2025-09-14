# Imagem oficial do Dart
FROM dart:stable

WORKDIR /app

# Copia todos os arquivos
COPY . .

# Resolve dependências
RUN dart pub get

# Porta do Render (usada pela env PORT)
EXPOSE 8080

# Comando para iniciar
CMD ["dart", "run", "main.dart"]
