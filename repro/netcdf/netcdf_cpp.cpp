#include <mpi.h>
#include <pnetcdf.h>
#include <iostream>

int main() {
  int ncid = 0;
  int rc = ncmpi_create(MPI_COMM_WORLD, "dummy.nc", NC_CLOBBER,
                        MPI_INFO_NULL, &ncid);
  if (rc != NC_NOERR) {
    std::cerr << "pnetcdf create failed" << std::endl;
    return 1;
  }
  ncmpi_close(ncid);
  return 0;
}
