program hdf5_test
  use hdf5
  implicit none
  integer :: ierr

  call h5open_f(ierr)
  call h5close_f(ierr)
end program hdf5_test
