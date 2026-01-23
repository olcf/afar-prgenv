#include <fftw3.h>
#include <iostream>

int main() {
  fftw_complex in[4];
  fftw_complex out[4];
  fftw_plan plan = fftw_plan_dft_1d(4, in, out, FFTW_FORWARD, FFTW_ESTIMATE);
  fftw_destroy_plan(plan);
  std::cout << "fftw plan created" << std::endl;
  return 0;
}
