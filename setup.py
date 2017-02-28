from distutils.core import setup, Extension
from Cython.Build import cythonize

extensions = [Extension("daryq", ["daryq.pyx"], language="c++",
                        extra_compile_args=["-std=c++11", "-stdlib=libc++", "-mmacosx-version-min=10.7"])]

setup(
    name='daryq',
    ext_modules=cythonize(extensions)
)
