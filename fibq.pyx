from libcpp cimport bool
from libcpp.unordered_map cimport unordered_map
from libcpp.pair cimport pair
from cpython.ref cimport PyObject
from cython.operator cimport dereference, preincrement
from cpython.ref cimport Py_INCREF, Py_DECREF

from collections import Mapping, Sized, Iterable

cdef extern from "<boost/heap/fibonacci_heap.hpp>" namespace "boost::heap":
    cdef cppclass fibonacci_heap[T]:
        cppclass ordered_iterator:
            T& operator*()
            ordered_iterator operator++()
            bool operator==(ordered_iterator)
        cppclass handle_type:
            T& operator*()
        fibonacci_heap()
        fibonacci_heap(const fibonacci_heap&)
        bool empty()
        int size()
        void clear()
        T top()
        handle_type push(const T&)
        void pop()
        void merge(const fibonacci_heap&)
        void update(fibonacci_heap.handle_type)
        void erase(const fibonacci_heap.handle_type&)
        ordered_iterator ordered_begin()
        ordered_iterator ordered_end()

ctypedef PyObject* PyObject_ptr
ctypedef fibonacci_heap[pair[int, PyObject_ptr]] fibq_type

cdef class fibq_it:
    cdef fibonacci_heap[pair[int, PyObject_ptr]].ordered_iterator it
    cdef fibonacci_heap[pair[int, PyObject_ptr]].ordered_iterator end

    @staticmethod
    cdef factory(fibonacci_heap[pair[int, PyObject_ptr]].ordered_iterator begin,
                 fibonacci_heap[pair[int, PyObject_ptr]].ordered_iterator end):
        it_ = fibq_it()
        it_.it = begin
        it_.end = end
        return it_

    def __next__(self):
        if self.it == self.end:
            raise StopIteration
        else:
            key = <object>dereference(self.it).second
            preincrement(self.it)
            return key

cdef class fibq:
    cdef fibq_type c_fibq
    cdef unordered_map[PyObject_ptr, fibq_type.handle_type] handles

    def __cinit__(self):
        self.c_fibq = fibq_type()

    def __dealloc__(self):
        for key in self:
            Py_DECREF(key)

    def __init__(self, iterable=None):
        if isinstance(iterable, Mapping):
            for k in iterable:
                self[k] = iterable[k]
        elif isinstance(iterable, Iterable):
            for pair in iterable:
                if isinstance(pair, Sized) and len(pair) == 2:
                    self[pair[0]] = pair[1]
                else:
                    raise ValueError
        elif iterable is not None:
            raise TypeError

    def __len__(self):
        return self.c_fibq.size()

    def __iter__(self):
        return fibq_it.factory(self.c_fibq.ordered_begin(),
                               self.c_fibq.ordered_end())

    def clear(self):
        self.c_fibq.clear()

    def __contains__(self, object key):
        cdef PyObject_ptr key_ = <PyObject_ptr>key
        cdef unordered_map[PyObject_ptr, fibq_type.handle_type].iterator it = self.handles.find(key_)

        if it == self.handles.end():
            return False
        else:
            return True

    def __getitem__(self, object key):
        cdef PyObject_ptr key_ = <PyObject_ptr>key
        cdef unordered_map[PyObject_ptr, fibq_type.handle_type].iterator it = self.handles.find(key_)

        if it == self.handles.end():
            raise KeyError

        return dereference(dereference(it).second).first

    def __setitem__(self, object key, int priority):
        # NOTE Cython bug, can't use fibq_type
        cdef fibonacci_heap[pair[int, PyObject_ptr]].handle_type handle
        cdef pair[int, PyObject_ptr] node
        cdef pair[PyObject_ptr, fibq_type.handle_type] lookup

        cdef PyObject_ptr key_ = <PyObject_ptr>key
        cdef unordered_map[PyObject_ptr, fibq_type.handle_type].iterator it = self.handles.find(key_)

        if it == self.handles.end():
            node = pair[int, PyObject_ptr](priority, key_)
            handle = self.c_fibq.push(node)
            lookup = pair[PyObject_ptr, fibq_type.handle_type](key_, handle)
            self.handles.insert(lookup)
            Py_INCREF(key)
        else:
            lookup = dereference(it)
            handle = lookup.second
            dereference(handle).first = priority
            self.c_fibq.update(handle)

    def __delitem__(self, object key):
        cdef fibonacci_heap[pair[int, PyObject_ptr]].handle_type handle

        cdef PyObject_ptr key_ = <PyObject_ptr>key
        cdef unordered_map[PyObject_ptr, fibq_type.handle_type].iterator it = self.handles.find(key_)

        if it == self.handles.end():
            raise KeyError

        handle = dereference(it).second
        self.c_fibq.erase(handle)
        Py_DECREF(key)

    def peek(self):
        if len(self) == 0:
            raise KeyError
        value = self.c_fibq.top()
        cdef object rval = <object>value.second
        Py_DECREF(rval)
        return rval

    cdef pair[int, PyObject_ptr] _pop(self):
        value = self.c_fibq.top()
        self.handles.erase(value.second)
        self.c_fibq.pop()
        return value

    def pop(self):
        if len(self) == 0:
            raise KeyError
        value = self._pop()
        cdef object rval = <object>value.second
        Py_DECREF(rval)
        return rval

    def popitem(self):
        if len(self) == 0:
            raise KeyError
        value = self._pop()
        cdef object rval = <object>value.second
        Py_DECREF(rval)
        cdef int priority = value.first
        return (priority, rval)

    def update(fibq self, fibq other):
        self.c_fibq.merge(other.c_fibq)
