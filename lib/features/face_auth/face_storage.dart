class InMemoryFaceStorage {
  static final InMemoryFaceStorage _instance = InMemoryFaceStorage._internal();

  factory InMemoryFaceStorage() {
    return _instance;
  }

  InMemoryFaceStorage._internal();

  List<double>? _registeredEmbedding;

  void saveEmbedding(List<double> embedding) {
    _registeredEmbedding = embedding;
  }

  List<double>? getEmbedding() {
    return _registeredEmbedding;
  }

  bool hasRegisteredFace() {
    return _registeredEmbedding != null;
  }
}
