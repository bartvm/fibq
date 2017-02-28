#include <boost/heap/d_ary_heap.hpp>

template<typename T>
using d_ary_heap = boost::heap::d_ary_heap<T, boost::heap::arity<2>, boost::heap::mutable_<true>>;
