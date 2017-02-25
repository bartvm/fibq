from distutils.core import setup, Extension
from Cython.Build import cythonize

extensions = [Extension("fibq", ["fibq.pyx"], language="c++",
                        extra_compile_args=["-std=c++11"])]

setup(
    name='fibq',
    ext_modules=cythonize(extensions),
)
