#include <mpi.h>
#include <pnetcdf.h>

int main(void) {
  int ncid = 0;
  int rc = ncmpi_create(MPI_COMM_WORLD, "dummy.nc", NC_CLOBBER,
                        MPI_INFO_NULL, &ncid);
  if (rc != NC_NOERR) {
    return 1;
  }
  ncmpi_close(ncid);
  return 0;
}
