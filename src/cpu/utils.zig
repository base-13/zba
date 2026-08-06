pub fn getNBits(number: u32, start: u5, n: u5, T: type) T {
    return @intCast((number >> start) & ((@as(u32, 1) << n) - 1));
}
