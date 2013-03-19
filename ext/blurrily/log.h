#ifdef DEBUG
#define LOG(...) fprintf(stderr, __VA_ARGS__)
#else
#define LOG(...)
#endif
