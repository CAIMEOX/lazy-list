///|
test "lazy list" {
  let l1 = LazyList::from_array([1, 2, 3, 4, 5, 6])
  let l2 = LazyList::from_array([7, 8, 9, 10, 11])
  inspect(l1, content="[1, 2, 3, 4, 5, 6]")
  inspect(l2, content="[7, 8, 9, 10, 11]")
  assert_true(l1 == l1)
  inspect(l1.zip_with(l2, Add::op_add), content="[8, 10, 12, 14, 16]")
  inspect(l1.index(3), content="4")
}

///|
test "lazy" {
  let x = nats()
  inspect(x.take(10), content="[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]")
  let y = nats().map(fn(x) { x + 10 })
  inspect(
    y.take(20),
    content="[10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29]",
  )
  let z = x.zip_with(y, Add::op_add)
  inspect(z.take(10), content="[10, 12, 14, 16, 18, 20, 22, 24, 26, 28]")
  inspect(
    z.drop(10).take(10),
    content="[30, 32, 34, 36, 38, 40, 42, 44, 46, 48]",
  )
  inspect(z.head(), content="10")
  inspect(z.tail().take(5), content="[12, 14, 16, 18, 20]")
}

///|
test "empty list operations" {
  let empty : LazyList[Unit] = Nil
  assert_true(empty == LazyList::from_array([]))
  assert_eq(empty.length(), 0)
  assert_eq(empty.to_array(), [])
  inspect(empty, content="[]")
}

///|
test "default construction" {
  let empty : LazyList[Unit] = default()
  assert_true(empty == Nil)
  assert_eq(empty.length(), 0)
}

///|
test "infinite operations" {
  let ones = repeat(1)
  inspect(ones.take(5), content="[1, 1, 1, 1, 1]")
  assert_eq(ones.take(10).length(), 10)
  assert_eq(ones.take(0), Nil)
}

///|
test "tails function" {
  let lst = LazyList::from_array([1, 2, 3])
  let t = lst.tails()
  inspect(t.index(0), content="[1, 2, 3]")
  inspect(t.index(1), content="[2, 3]")
  inspect(t.index(2), content="[3]")
  inspect(t.index(3), content="[]")
}

///|
test "edge cases for indexing" {
  let lst = LazyList::from_array([10, 20, 30])
  assert_eq(lst.index(0), 10)
  assert_eq(lst.index(2), 30)
}

///|
test "filter operations" {
  let nums = nats().take(10)
  let evens = nums.filter(fn(x) { x % 2 == 0 })
  inspect(evens, content="[0, 2, 4, 6, 8]")
  let empty_filter = nums.filter(fn(_) { false })
  assert_true(empty_filter == Nil)
}

///|
test "split_at edge cases" {
  let lst = LazyList::from_array([1, 2, 3, 4])
  let (a, b) = lst.split_at(0)
  assert_true(a == Nil)
  assert_true(b == lst)
  let (c, d) = lst.split_at(5)
  assert_eq(c.length(), 4)
  assert_true(d == Nil)
}

///|
test "fold operations" {
  let lst = LazyList::from_array([1, 2, 3])
  assert_eq(lst.fold_left(Add::op_add, init=0), 6)
  assert_eq(lst.fold_left(Mul::op_mul, init=1), 6)
  assert_eq(lst.fold_right(Add::op_add, init=0), 6)
}

///|
test "unzip operation" {
  let pairs = LazyList::from_array([(1, "a"), (2, "b"), (3, "c")])
  let (nums, chars) = pairs.unzip()
  inspect(nums, content="[1, 2, 3]")
  inspect(chars, content="[a, b, c]")
}

///|
test "flat_map operations" {
  let lst = LazyList::from_array([1, 2, 3])
  let expanded = lst.flat_map(fn(x) { LazyList::from_array([x, x * 10]) })
  inspect(expanded, content="[1, 10, 2, 20, 3, 30]")
  let empty_flat : LazyList[Int] = lst.flat_map(fn(_) {
    LazyList::from_array([])
  })
  assert_true(empty_flat == Nil)
}

///|
test "drop operations" {
  let lst = LazyList::from_array([1, 2, 3, 4, 5])
  assert_true(lst.drop(0) == lst)
  assert_true(lst.drop(5) == Nil)
  inspect(lst.drop(2), content="[3, 4, 5]")
  inspect(lst.drop_while(fn(x) { x < 3 }), content="[3, 4, 5]")
}

///|
test "take_while edge cases" {
  let lst = LazyList::from_array([2, 4, 6, 7, 8])
  let taken = lst.take_while(fn(x) { x % 2 == 0 })
  inspect(taken, content="[2, 4, 6]")
  let none_taken = lst.take_while(fn(_) { false })
  assert_true(none_taken == Nil)
}

///|
test "zip_with different lengths" {
  let short = LazyList::from_array([1, 2])
  let long = LazyList::from_array([10, 20, 30])
  let zipped1 = short.zip_with(long, Add::op_add)
  inspect(zipped1, content="[11, 22]")
  let zipped2 = long.zip_with(short, Add::op_add)
  inspect(zipped2, content="[11, 22]")
}

///|
test "flatten operation" {
  let lists = LazyList::from_array([
    LazyList::from_array([1, 2]),
    LazyList::from_array([3]),
    LazyList::from_array([4, 5]),
  ])
  let flat = lists.flatten()
  inspect(flat, content="[1, 2, 3, 4, 5]")
}

///|
test "infinite stream generation" {
  let tens = infinite_stream(0, 10)
  inspect(tens.take(5), content="[0, 10, 20, 30, 40]")
  let decimals = infinite_stream(0.1, 0.1)
  inspect(
    decimals.take(3).to_array().map(fn(x) { x.to_string() }),
    content=(
      #|["0.1", "0.2", "0.30000000000000004"]
    ),
  )
}

///|
test "head and tail edge cases" {
  let single = LazyList::from_array([42])
  assert_eq(single.head(), 42)
  assert_true(single.tail() == Nil)
}
