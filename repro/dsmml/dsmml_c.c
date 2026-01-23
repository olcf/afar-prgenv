#include "dsmml.h"

int main(void) {
  int major = 0;
  int minor = 0;
  dsmml_get_version_info(&major, &minor);
  return 0;
}
