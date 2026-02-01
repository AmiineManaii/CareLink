import 'dart:math';

class FaceCompareService {
  // Calcule la distance euclidienne entre deux embeddings
  static double euclideanDistance(List<double> e1, List<double> e2) {
    double sum = 0;
    for (int i = 0; i < e1.length; i++) {
      sum += pow(e1[i] - e2[i], 2);
    }
    return sqrt(sum);
  }

  // Vérifie si l'embedding correspond à l'utilisateur
  static bool match(List<double> e1, List<double> e2, {double threshold = 0.8}) {
    return euclideanDistance(e1, e2) < threshold;
  }
}
