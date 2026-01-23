#include "hdf5.h"

int main(void) {
  hid_t file = H5Fcreate("dummy.h5", H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT);
  if (file < 0) {
    return 1;
  }
  H5Fclose(file);
  return 0;
}
