program fftw_test
  use, intrinsic :: iso_c_binding
  implicit none
  include 'fftw3.f03'

  complex(C_DOUBLE_COMPLEX) :: in(4), out(4)
  type(C_PTR) :: plan

  plan = fftw_plan_dft_1d(4, in, out, FFTW_FORWARD, FFTW_ESTIMATE)
  call fftw_destroy_plan(plan)
end program fftw_test
