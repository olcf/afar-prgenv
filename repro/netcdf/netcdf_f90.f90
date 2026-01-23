program pnetcdf_test
  use mpi
  implicit none
  include 'pnetcdf.inc'
  integer :: ncid
  integer :: rc

  rc = nfmpi_create(MPI_COMM_WORLD, 'dummy.nc', NF_CLOBBER, MPI_INFO_NULL, ncid)
  if (rc == NF_NOERR) then
    rc = nfmpi_close(ncid)
  end if
end program pnetcdf_test
