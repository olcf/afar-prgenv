#include <stdio.h>

extern void dgemm_(const char *transa, const char *transb,
                   const int *m, const int *n, const int *k,
                   const double *alpha, const double *a, const int *lda,
                   const double *b, const int *ldb,
                   const double *beta, double *c, const int *ldc);

int main(void) {
  int n = 2;
  double a[4] = {1.0, 0.0, 0.0, 1.0};
  double b[4] = {1.0, 2.0, 3.0, 4.0};
  double c[4] = {0.0, 0.0, 0.0, 0.0};
  double alpha = 1.0;
  double beta = 0.0;
  dgemm_("N", "N", &n, &n, &n, &alpha, a, &n, b, &n, &beta, c, &n);
  printf("C[0]=%g\n", c[0]);
  return 0;
}
