from libcpp cimport bool
from libcpp.unordered_map cimport unordered_map
from libcpp.pair cimport pair
from cpython.ref cimport PyObject
from cython.operator cimport dereference, preincrement
from cpython.ref cimport Py_INCREF, Py_DECREF

from collections import Mapping, Sized, Iterable

cdef extern from "d_ary_heap.hpp":
    cdef cppclass d_ary_heap[T]:
        cppclass ordered_iterator:
            ordered_iterator()
            T& operator*()
            ordered_iterator operator++()
            bool operator==(ordered_iterator)
        cppclass handle_type:
            T& operator*()
        d_ary_heap()
        d_ary_heap(const d_ary_heap&)
        bool empty()
        int size()
        void clear()
        T top()
        handle_type push(const T&)
        void pop()
        void update(d_ary_heap.handle_type)
        void erase(const d_ary_heap.handle_type&)
        ordered_iterator ordered_begin()
        ordered_iterator ordered_end()

ctypedef PyObject* PyObject_ptr
ctypedef d_ary_heap[pair[int, PyObject_ptr]] daryq_type

cdef class daryq_it:
    # NOTE The default constructor of the ordered_iterator in
    # boost/heap/detail/mutable_heap.hpp was fixed
    cdef d_ary_heap[pair[int, PyObject_ptr]].ordered_iterator it
    cdef d_ary_heap[pair[int, PyObject_ptr]].ordered_iterator end

    @staticmethod
    cdef factory(d_ary_heap[pair[int, PyObject_ptr]].ordered_iterator begin,
                 d_ary_heap[pair[int, PyObject_ptr]].ordered_iterator end):
        it_ = daryq_it()
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

cdef class daryq:
    cdef daryq_type c_daryq
    cdef unordered_map[PyObject_ptr, daryq_type.handle_type] handles

    def __cinit__(self):
        self.c_daryq = daryq_type()

    def __dealloc__(self):
        cdef unordered_map[PyObject_ptr, daryq_type.handle_type].iterator it
        it = self.handles.begin()
        while it != self.handles.end():
            Py_DECREF(<object>dereference(it).first)
            preincrement(it)

    def __init__(self, iterable=None):
        if isinstance(iterable, Mapping):
            for k, v in iterable.items():
                self.push(k, v)
        elif isinstance(iterable, Iterable):
            for pair in iterable:
                if isinstance(pair, Sized) and len(pair) == 2:
                    self.push(*pair)
                else:
                    raise ValueError
        elif iterable is not None:
            raise TypeError

    def __len__(self):
        return self.c_daryq.size()

    def __iter__(self):
        # For some reason, calling ordered_begin/end in daryq_it doesn't work
        return daryq_it.factory(self.c_daryq.ordered_begin(),
                                self.c_daryq.ordered_end())

    def clear(self):
        self.c_daryq.clear()

    def __contains__(self, object key):
        cdef PyObject_ptr key_ = <PyObject_ptr>key
        cdef unordered_map[PyObject_ptr, daryq_type.handle_type].iterator it = self.handles.find(key_)

        if it == self.handles.end():
            return False
        else:
            return True

    def __getitem__(self, object key):
        cdef PyObject_ptr key_ = <PyObject_ptr>key
        cdef unordered_map[PyObject_ptr, daryq_type.handle_type].iterator it = self.handles.find(key_)

        if it == self.handles.end():
            raise KeyError

        return dereference(dereference(it).second).first

    cpdef push(self, object key, int priority):
        cdef d_ary_heap[pair[int, PyObject_ptr]].handle_type handle
        cdef pair[int, PyObject_ptr] node
        cdef pair[PyObject_ptr, daryq_type.handle_type] lookup
        cdef PyObject_ptr key_ = <PyObject_ptr>key

        node = pair[int, PyObject_ptr](priority, key_)
        handle = self.c_daryq.push(node)
        lookup = pair[PyObject_ptr, daryq_type.handle_type](key_, handle)
        self.handles.insert(lookup)
        Py_INCREF(key)

    cpdef replace(self, object key, int priority):
        # NOTE Cython bug, can't use daryq_type
        cdef d_ary_heap[pair[int, PyObject_ptr]].handle_type handle
        cdef pair[int, PyObject_ptr] node
        cdef pair[PyObject_ptr, daryq_type.handle_type] lookup

        cdef PyObject_ptr key_ = <PyObject_ptr>key
        cdef unordered_map[PyObject_ptr, daryq_type.handle_type].iterator it = self.handles.find(key_)

        if it == self.handles.end():
            self.push(key, priority)
        else:
            lookup = dereference(it)
            handle = lookup.second
            dereference(handle).first = priority
            self.c_daryq.update(handle)

    def __setitem__(self, object key, int priority):
        self.replace(key, priority)

    def __delitem__(self, object key):
        cdef d_ary_heap[pair[int, PyObject_ptr]].handle_type handle

        cdef PyObject_ptr key_ = <PyObject_ptr>key
        cdef unordered_map[PyObject_ptr, daryq_type.handle_type].iterator it = self.handles.find(key_)

        if it == self.handles.end():
            raise KeyError

        handle = dereference(it).second
        self.c_daryq.erase(handle)
        Py_DECREF(key)

    def peek(self):
        if self.c_daryq.empty():
            raise KeyError
        value = self.c_daryq.top()
        cdef object rval = <object>value.second
        Py_DECREF(rval)
        return rval

    cdef pair[int, PyObject_ptr] _pop(self):
        value = self.c_daryq.top()
        self.handles.erase(value.second)
        self.c_daryq.pop()
        return value

    def pop(self):
        if self.c_daryq.empty():
            raise KeyError
        value = self._pop()
        cdef object rval = <object>value.second
        Py_DECREF(rval)
        return rval

    def popitem(self):
        if self.c_daryq.empty():
            raise KeyError
        value = self._pop()
        cdef object rval = <object>value.second
        Py_DECREF(rval)
        cdef int priority = value.first
        return (priority, rval)

    def update(daryq self, daryq other):
        raise NotImplementedError
