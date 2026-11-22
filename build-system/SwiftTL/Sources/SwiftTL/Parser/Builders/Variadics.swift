// BEGIN AUTO-GENERATED CONTENT

extension ParserBuilder {
  public struct ZipOO<P0: Parser, P1: Parser>: Parser
  where
    P0.Input == P1.Input
  {
    public let p0: P0, p1: P1

    @inlinable public init(_ p0: P0, _ p1: P1) {
      self.p0 = p0
      self.p1 = p1
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        return (o0, o1)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1>(
    _ p0: P0, _ p1: P1
  ) -> ParserBuilder.ZipOO<P0, P1> {
    ParserBuilder.ZipOO(p0, p1)
  }
}

extension ParserBuilder {
  public struct ZipOV<P0: Parser, P1: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Output == Void
  {
    public let p0: P0, p1: P1

    @inlinable public init(_ p0: P0, _ p1: P1) {
      self.p0 = p0
      self.p1 = p1
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P0.Output {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        return o0
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1>(
    _ p0: P0, _ p1: P1
  ) -> ParserBuilder.ZipOV<P0, P1> {
    ParserBuilder.ZipOV(p0, p1)
  }
}

extension ParserBuilder {
  public struct ZipVO<P0: Parser, P1: Parser>: Parser
  where
    P0.Input == P1.Input,
    P0.Output == Void
  {
    public let p0: P0, p1: P1

    @inlinable public init(_ p0: P0, _ p1: P1) {
      self.p0 = p0
      self.p1 = p1
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P1.Output {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        return o1
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1>(
    _ p0: P0, _ p1: P1
  ) -> ParserBuilder.ZipVO<P0, P1> {
    ParserBuilder.ZipVO(p0, p1)
  }
}

extension ParserBuilder {
  public struct ZipVV<P0: Parser, P1: Parser>: Parser
  where
    P0.Input == P1.Input,
    P0.Output == Void,
    P1.Output == Void
  {
    public let p0: P0, p1: P1

    @inlinable public init(_ p0: P0, _ p1: P1) {
      self.p0 = p0
      self.p1 = p1
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1>(
    _ p0: P0, _ p1: P1
  ) -> ParserBuilder.ZipVV<P0, P1> {
    ParserBuilder.ZipVV(p0, p1)
  }
}

extension ParserBuilder {
  public struct ZipOOO<P0: Parser, P1: Parser, P2: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input
  {
    public let p0: P0, p1: P1, p2: P2

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P2.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        return (o0, o1, o2)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2>(
    _ p0: P0, _ p1: P1, _ p2: P2
  ) -> ParserBuilder.ZipOOO<P0, P1, P2> {
    ParserBuilder.ZipOOO(p0, p1, p2)
  }
}

extension ParserBuilder {
  public struct ZipOOV<P0: Parser, P1: Parser, P2: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        return (o0, o1)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2>(
    _ p0: P0, _ p1: P1, _ p2: P2
  ) -> ParserBuilder.ZipOOV<P0, P1, P2> {
    ParserBuilder.ZipOOV(p0, p1, p2)
  }
}

extension ParserBuilder {
  public struct ZipOVO<P0: Parser, P1: Parser, P2: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P1.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P2.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        return (o0, o2)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2>(
    _ p0: P0, _ p1: P1, _ p2: P2
  ) -> ParserBuilder.ZipOVO<P0, P1, P2> {
    ParserBuilder.ZipOVO(p0, p1, p2)
  }
}

extension ParserBuilder {
  public struct ZipOVV<P0: Parser, P1: Parser, P2: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P1.Output == Void,
    P2.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P0.Output {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        return o0
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2>(
    _ p0: P0, _ p1: P1, _ p2: P2
  ) -> ParserBuilder.ZipOVV<P0, P1, P2> {
    ParserBuilder.ZipOVV(p0, p1, p2)
  }
}

extension ParserBuilder {
  public struct ZipVOO<P0: Parser, P1: Parser, P2: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P0.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P2.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        return (o1, o2)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2>(
    _ p0: P0, _ p1: P1, _ p2: P2
  ) -> ParserBuilder.ZipVOO<P0, P1, P2> {
    ParserBuilder.ZipVOO(p0, p1, p2)
  }
}

extension ParserBuilder {
  public struct ZipVOV<P0: Parser, P1: Parser, P2: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P0.Output == Void,
    P2.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P1.Output {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        return o1
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2>(
    _ p0: P0, _ p1: P1, _ p2: P2
  ) -> ParserBuilder.ZipVOV<P0, P1, P2> {
    ParserBuilder.ZipVOV(p0, p1, p2)
  }
}

extension ParserBuilder {
  public struct ZipVVO<P0: Parser, P1: Parser, P2: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P0.Output == Void,
    P1.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P2.Output {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        return o2
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2>(
    _ p0: P0, _ p1: P1, _ p2: P2
  ) -> ParserBuilder.ZipVVO<P0, P1, P2> {
    ParserBuilder.ZipVVO(p0, p1, p2)
  }
}

extension ParserBuilder {
  public struct ZipVVV<P0: Parser, P1: Parser, P2: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P0.Output == Void,
    P1.Output == Void,
    P2.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2>(
    _ p0: P0, _ p1: P1, _ p2: P2
  ) -> ParserBuilder.ZipVVV<P0, P1, P2> {
    ParserBuilder.ZipVVV(p0, p1, p2)
  }
}

extension ParserBuilder {
  public struct ZipOOOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P2.Output,
      P3.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        return (o0, o1, o2, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3
  ) -> ParserBuilder.ZipOOOO<P0, P1, P2, P3> {
    ParserBuilder.ZipOOOO(p0, p1, p2, p3)
  }
}

extension ParserBuilder {
  public struct ZipOOOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P2.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        return (o0, o1, o2)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3
  ) -> ParserBuilder.ZipOOOV<P0, P1, P2, P3> {
    ParserBuilder.ZipOOOV(p0, p1, p2, p3)
  }
}

extension ParserBuilder {
  public struct ZipOOVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P2.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P3.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        return (o0, o1, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3
  ) -> ParserBuilder.ZipOOVO<P0, P1, P2, P3> {
    ParserBuilder.ZipOOVO(p0, p1, p2, p3)
  }
}

extension ParserBuilder {
  public struct ZipOOVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P2.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        return (o0, o1)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3
  ) -> ParserBuilder.ZipOOVV<P0, P1, P2, P3> {
    ParserBuilder.ZipOOVV(p0, p1, p2, p3)
  }
}

extension ParserBuilder {
  public struct ZipOVOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P1.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P2.Output,
      P3.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        return (o0, o2, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3
  ) -> ParserBuilder.ZipOVOO<P0, P1, P2, P3> {
    ParserBuilder.ZipOVOO(p0, p1, p2, p3)
  }
}

extension ParserBuilder {
  public struct ZipOVOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P1.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P2.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        return (o0, o2)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3
  ) -> ParserBuilder.ZipOVOV<P0, P1, P2, P3> {
    ParserBuilder.ZipOVOV(p0, p1, p2, p3)
  }
}

extension ParserBuilder {
  public struct ZipOVVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P1.Output == Void,
    P2.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P3.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        return (o0, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3
  ) -> ParserBuilder.ZipOVVO<P0, P1, P2, P3> {
    ParserBuilder.ZipOVVO(p0, p1, p2, p3)
  }
}

extension ParserBuilder {
  public struct ZipOVVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P1.Output == Void,
    P2.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P0.Output {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        return o0
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3
  ) -> ParserBuilder.ZipOVVV<P0, P1, P2, P3> {
    ParserBuilder.ZipOVVV(p0, p1, p2, p3)
  }
}

extension ParserBuilder {
  public struct ZipVOOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P0.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P2.Output,
      P3.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        return (o1, o2, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3
  ) -> ParserBuilder.ZipVOOO<P0, P1, P2, P3> {
    ParserBuilder.ZipVOOO(p0, p1, p2, p3)
  }
}

extension ParserBuilder {
  public struct ZipVOOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P0.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P2.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        return (o1, o2)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3
  ) -> ParserBuilder.ZipVOOV<P0, P1, P2, P3> {
    ParserBuilder.ZipVOOV(p0, p1, p2, p3)
  }
}

extension ParserBuilder {
  public struct ZipVOVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P0.Output == Void,
    P2.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P3.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        return (o1, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3
  ) -> ParserBuilder.ZipVOVO<P0, P1, P2, P3> {
    ParserBuilder.ZipVOVO(p0, p1, p2, p3)
  }
}

extension ParserBuilder {
  public struct ZipVOVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P0.Output == Void,
    P2.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P1.Output {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        return o1
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3
  ) -> ParserBuilder.ZipVOVV<P0, P1, P2, P3> {
    ParserBuilder.ZipVOVV(p0, p1, p2, p3)
  }
}

extension ParserBuilder {
  public struct ZipVVOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P0.Output == Void,
    P1.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P2.Output,
      P3.Output
    ) {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        return (o2, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3
  ) -> ParserBuilder.ZipVVOO<P0, P1, P2, P3> {
    ParserBuilder.ZipVVOO(p0, p1, p2, p3)
  }
}

extension ParserBuilder {
  public struct ZipVVOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P0.Output == Void,
    P1.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P2.Output {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        return o2
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3
  ) -> ParserBuilder.ZipVVOV<P0, P1, P2, P3> {
    ParserBuilder.ZipVVOV(p0, p1, p2, p3)
  }
}

extension ParserBuilder {
  public struct ZipVVVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P0.Output == Void,
    P1.Output == Void,
    P2.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P3.Output {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        return o3
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3
  ) -> ParserBuilder.ZipVVVO<P0, P1, P2, P3> {
    ParserBuilder.ZipVVVO(p0, p1, p2, p3)
  }
}

extension ParserBuilder {
  public struct ZipVVVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P0.Output == Void,
    P1.Output == Void,
    P2.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3
  ) -> ParserBuilder.ZipVVVV<P0, P1, P2, P3> {
    ParserBuilder.ZipVVVV(p0, p1, p2, p3)
  }
}

extension ParserBuilder {
  public struct ZipOOOOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P2.Output,
      P3.Output,
      P4.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        return (o0, o1, o2, o3, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipOOOOO<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipOOOOO(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipOOOOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P2.Output,
      P3.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        return (o0, o1, o2, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipOOOOV<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipOOOOV(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipOOOVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P2.Output,
      P4.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        return (o0, o1, o2, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipOOOVO<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipOOOVO(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipOOOVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P3.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P2.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        return (o0, o1, o2)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipOOOVV<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipOOOVV(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipOOVOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P2.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P3.Output,
      P4.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        return (o0, o1, o3, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipOOVOO<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipOOVOO(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipOOVOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P2.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P3.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        return (o0, o1, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipOOVOV<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipOOVOV(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipOOVVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P2.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P4.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        return (o0, o1, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipOOVVO<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipOOVVO(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipOOVVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P2.Output == Void,
    P3.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        return (o0, o1)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipOOVVV<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipOOVVV(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipOVOOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P1.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P2.Output,
      P3.Output,
      P4.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        return (o0, o2, o3, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipOVOOO<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipOVOOO(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipOVOOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P1.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P2.Output,
      P3.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        return (o0, o2, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipOVOOV<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipOVOOV(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipOVOVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P1.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P2.Output,
      P4.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        return (o0, o2, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipOVOVO<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipOVOVO(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipOVOVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P1.Output == Void,
    P3.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P2.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        return (o0, o2)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipOVOVV<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipOVOVV(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipOVVOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P1.Output == Void,
    P2.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P3.Output,
      P4.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        return (o0, o3, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipOVVOO<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipOVVOO(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipOVVOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P1.Output == Void,
    P2.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P3.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        return (o0, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipOVVOV<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipOVVOV(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipOVVVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P1.Output == Void,
    P2.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P4.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        return (o0, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipOVVVO<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipOVVVO(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipOVVVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P1.Output == Void,
    P2.Output == Void,
    P3.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P0.Output {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        return o0
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipOVVVV<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipOVVVV(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipVOOOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P0.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P2.Output,
      P3.Output,
      P4.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        return (o1, o2, o3, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipVOOOO<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipVOOOO(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipVOOOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P0.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P2.Output,
      P3.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        return (o1, o2, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipVOOOV<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipVOOOV(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipVOOVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P0.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P2.Output,
      P4.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        return (o1, o2, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipVOOVO<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipVOOVO(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipVOOVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P0.Output == Void,
    P3.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P2.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        return (o1, o2)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipVOOVV<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipVOOVV(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipVOVOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P0.Output == Void,
    P2.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P3.Output,
      P4.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        return (o1, o3, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipVOVOO<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipVOVOO(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipVOVOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P0.Output == Void,
    P2.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P3.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        return (o1, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipVOVOV<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipVOVOV(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipVOVVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P0.Output == Void,
    P2.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P4.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        return (o1, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipVOVVO<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipVOVVO(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipVOVVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P0.Output == Void,
    P2.Output == Void,
    P3.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P1.Output {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        return o1
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipVOVVV<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipVOVVV(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipVVOOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P0.Output == Void,
    P1.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P2.Output,
      P3.Output,
      P4.Output
    ) {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        return (o2, o3, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipVVOOO<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipVVOOO(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipVVOOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P0.Output == Void,
    P1.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P2.Output,
      P3.Output
    ) {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        return (o2, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipVVOOV<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipVVOOV(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipVVOVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P0.Output == Void,
    P1.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P2.Output,
      P4.Output
    ) {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        return (o2, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipVVOVO<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipVVOVO(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipVVOVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P0.Output == Void,
    P1.Output == Void,
    P3.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P2.Output {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        return o2
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipVVOVV<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipVVOVV(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipVVVOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P0.Output == Void,
    P1.Output == Void,
    P2.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P3.Output,
      P4.Output
    ) {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        return (o3, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipVVVOO<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipVVVOO(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipVVVOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P0.Output == Void,
    P1.Output == Void,
    P2.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P3.Output {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        return o3
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipVVVOV<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipVVVOV(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipVVVVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P0.Output == Void,
    P1.Output == Void,
    P2.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P4.Output {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        return o4
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipVVVVO<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipVVVVO(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipVVVVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P0.Output == Void,
    P1.Output == Void,
    P2.Output == Void,
    P3.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> ParserBuilder.ZipVVVVV<P0, P1, P2, P3, P4> {
    ParserBuilder.ZipVVVVV(p0, p1, p2, p3, p4)
  }
}

extension ParserBuilder {
  public struct ZipOOOOOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P2.Output,
      P3.Output,
      P4.Output,
      P5.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o0, o1, o2, o3, o4, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOOOOOO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOOOOOO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOOOOOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P2.Output,
      P3.Output,
      P4.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        try p5.parse(&input)
        return (o0, o1, o2, o3, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOOOOOV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOOOOOV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOOOOVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P2.Output,
      P3.Output,
      P5.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o0, o1, o2, o3, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOOOOVO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOOOOVO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOOOOVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P4.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P2.Output,
      P3.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        try p5.parse(&input)
        return (o0, o1, o2, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOOOOVV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOOOOVV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOOOVOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P2.Output,
      P4.Output,
      P5.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o0, o1, o2, o4, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOOOVOO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOOOVOO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOOOVOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P3.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P2.Output,
      P4.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        try p5.parse(&input)
        return (o0, o1, o2, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOOOVOV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOOOVOV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOOOVVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P3.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P2.Output,
      P5.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o0, o1, o2, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOOOVVO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOOOVVO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOOOVVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P3.Output == Void,
    P4.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P2.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        try p5.parse(&input)
        return (o0, o1, o2)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOOOVVV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOOOVVV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOOVOOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P2.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P3.Output,
      P4.Output,
      P5.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o0, o1, o3, o4, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOOVOOO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOOVOOO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOOVOOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P2.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P3.Output,
      P4.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        try p5.parse(&input)
        return (o0, o1, o3, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOOVOOV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOOVOOV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOOVOVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P2.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P3.Output,
      P5.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o0, o1, o3, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOOVOVO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOOVOVO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOOVOVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P2.Output == Void,
    P4.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P3.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        try p5.parse(&input)
        return (o0, o1, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOOVOVV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOOVOVV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOOVVOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P2.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P4.Output,
      P5.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o0, o1, o4, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOOVVOO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOOVVOO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOOVVOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P2.Output == Void,
    P3.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P4.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        try p5.parse(&input)
        return (o0, o1, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOOVVOV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOOVVOV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOOVVVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P2.Output == Void,
    P3.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output,
      P5.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o0, o1, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOOVVVO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOOVVVO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOOVVVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P2.Output == Void,
    P3.Output == Void,
    P4.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P1.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        try p5.parse(&input)
        return (o0, o1)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOOVVVV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOOVVVV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOVOOOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P1.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P2.Output,
      P3.Output,
      P4.Output,
      P5.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o0, o2, o3, o4, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOVOOOO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOVOOOO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOVOOOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P1.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P2.Output,
      P3.Output,
      P4.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        try p5.parse(&input)
        return (o0, o2, o3, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOVOOOV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOVOOOV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOVOOVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P1.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P2.Output,
      P3.Output,
      P5.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o0, o2, o3, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOVOOVO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOVOOVO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOVOOVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P1.Output == Void,
    P4.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P2.Output,
      P3.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        try p5.parse(&input)
        return (o0, o2, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOVOOVV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOVOOVV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOVOVOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P1.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P2.Output,
      P4.Output,
      P5.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o0, o2, o4, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOVOVOO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOVOVOO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOVOVOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P1.Output == Void,
    P3.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P2.Output,
      P4.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        try p5.parse(&input)
        return (o0, o2, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOVOVOV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOVOVOV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOVOVVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P1.Output == Void,
    P3.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P2.Output,
      P5.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o0, o2, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOVOVVO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOVOVVO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOVOVVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P1.Output == Void,
    P3.Output == Void,
    P4.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P2.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        try p5.parse(&input)
        return (o0, o2)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOVOVVV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOVOVVV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOVVOOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P1.Output == Void,
    P2.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P3.Output,
      P4.Output,
      P5.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o0, o3, o4, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOVVOOO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOVVOOO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOVVOOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P1.Output == Void,
    P2.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P3.Output,
      P4.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        try p5.parse(&input)
        return (o0, o3, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOVVOOV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOVVOOV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOVVOVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P1.Output == Void,
    P2.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P3.Output,
      P5.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o0, o3, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOVVOVO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOVVOVO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOVVOVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P1.Output == Void,
    P2.Output == Void,
    P4.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P3.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        try p5.parse(&input)
        return (o0, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOVVOVV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOVVOVV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOVVVOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P1.Output == Void,
    P2.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P4.Output,
      P5.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o0, o4, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOVVVOO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOVVVOO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOVVVOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P1.Output == Void,
    P2.Output == Void,
    P3.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P4.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        try p5.parse(&input)
        return (o0, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOVVVOV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOVVVOV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOVVVVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P1.Output == Void,
    P2.Output == Void,
    P3.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P0.Output,
      P5.Output
    ) {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o0, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOVVVVO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOVVVVO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipOVVVVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P1.Output == Void,
    P2.Output == Void,
    P3.Output == Void,
    P4.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P0.Output {
      do {
        let o0 = try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        try p5.parse(&input)
        return o0
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipOVVVVV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipOVVVVV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVOOOOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P2.Output,
      P3.Output,
      P4.Output,
      P5.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o1, o2, o3, o4, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVOOOOO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVOOOOO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVOOOOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P2.Output,
      P3.Output,
      P4.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        try p5.parse(&input)
        return (o1, o2, o3, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVOOOOV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVOOOOV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVOOOVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P2.Output,
      P3.Output,
      P5.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o1, o2, o3, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVOOOVO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVOOOVO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVOOOVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P4.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P2.Output,
      P3.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        try p5.parse(&input)
        return (o1, o2, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVOOOVV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVOOOVV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVOOVOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P2.Output,
      P4.Output,
      P5.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o1, o2, o4, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVOOVOO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVOOVOO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVOOVOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P3.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P2.Output,
      P4.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        try p5.parse(&input)
        return (o1, o2, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVOOVOV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVOOVOV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVOOVVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P3.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P2.Output,
      P5.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o1, o2, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVOOVVO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVOOVVO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVOOVVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P3.Output == Void,
    P4.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P2.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        try p5.parse(&input)
        return (o1, o2)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVOOVVV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVOOVVV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVOVOOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P2.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P3.Output,
      P4.Output,
      P5.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o1, o3, o4, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVOVOOO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVOVOOO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVOVOOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P2.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P3.Output,
      P4.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        try p5.parse(&input)
        return (o1, o3, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVOVOOV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVOVOOV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVOVOVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P2.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P3.Output,
      P5.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o1, o3, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVOVOVO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVOVOVO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVOVOVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P2.Output == Void,
    P4.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P3.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        try p5.parse(&input)
        return (o1, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVOVOVV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVOVOVV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVOVVOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P2.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P4.Output,
      P5.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o1, o4, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVOVVOO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVOVVOO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVOVVOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P2.Output == Void,
    P3.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P4.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        try p5.parse(&input)
        return (o1, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVOVVOV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVOVVOV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVOVVVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P2.Output == Void,
    P3.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P1.Output,
      P5.Output
    ) {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o1, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVOVVVO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVOVVVO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVOVVVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P2.Output == Void,
    P3.Output == Void,
    P4.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P1.Output {
      do {
        try p0.parse(&input)
        let o1 = try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        try p5.parse(&input)
        return o1
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVOVVVV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVOVVVV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVVOOOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P1.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P2.Output,
      P3.Output,
      P4.Output,
      P5.Output
    ) {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o2, o3, o4, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVVOOOO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVVOOOO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVVOOOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P1.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P2.Output,
      P3.Output,
      P4.Output
    ) {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        try p5.parse(&input)
        return (o2, o3, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVVOOOV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVVOOOV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVVOOVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P1.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P2.Output,
      P3.Output,
      P5.Output
    ) {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o2, o3, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVVOOVO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVVOOVO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVVOOVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P1.Output == Void,
    P4.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P2.Output,
      P3.Output
    ) {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        try p5.parse(&input)
        return (o2, o3)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVVOOVV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVVOOVV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVVOVOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P1.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P2.Output,
      P4.Output,
      P5.Output
    ) {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o2, o4, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVVOVOO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVVOVOO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVVOVOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P1.Output == Void,
    P3.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P2.Output,
      P4.Output
    ) {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        try p5.parse(&input)
        return (o2, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVVOVOV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVVOVOV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVVOVVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P1.Output == Void,
    P3.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P2.Output,
      P5.Output
    ) {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o2, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVVOVVO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVVOVVO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVVOVVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P1.Output == Void,
    P3.Output == Void,
    P4.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P2.Output {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        let o2 = try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        try p5.parse(&input)
        return o2
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVVOVVV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVVOVVV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVVVOOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P1.Output == Void,
    P2.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P3.Output,
      P4.Output,
      P5.Output
    ) {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o3, o4, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVVVOOO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVVVOOO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVVVOOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P1.Output == Void,
    P2.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P3.Output,
      P4.Output
    ) {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        let o4 = try p4.parse(&input)
        try p5.parse(&input)
        return (o3, o4)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVVVOOV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVVVOOV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVVVOVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P1.Output == Void,
    P2.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P3.Output,
      P5.Output
    ) {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o3, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVVVOVO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVVVOVO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVVVOVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P1.Output == Void,
    P2.Output == Void,
    P4.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P3.Output {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        let o3 = try p3.parse(&input)
        try p4.parse(&input)
        try p5.parse(&input)
        return o3
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVVVOVV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVVVOVV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVVVVOO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P1.Output == Void,
    P2.Output == Void,
    P3.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> (
      P4.Output,
      P5.Output
    ) {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return (o4, o5)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVVVVOO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVVVVOO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVVVVOV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P1.Output == Void,
    P2.Output == Void,
    P3.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P4.Output {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        let o4 = try p4.parse(&input)
        try p5.parse(&input)
        return o4
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVVVVOV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVVVVOV(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVVVVVO<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P1.Output == Void,
    P2.Output == Void,
    P3.Output == Void,
    P4.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P5.Output {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        let o5 = try p5.parse(&input)
        return o5
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVVVVVO<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVVVVVO(p0, p1, p2, p3, p4, p5)
  }
}

extension ParserBuilder {
  public struct ZipVVVVVV<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == Void,
    P1.Output == Void,
    P2.Output == Void,
    P3.Output == Void,
    P4.Output == Void,
    P5.Output == Void
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows {
      do {
        try p0.parse(&input)
        try p1.parse(&input)
        try p2.parse(&input)
        try p3.parse(&input)
        try p4.parse(&input)
        try p5.parse(&input)
      } catch { throw ParsingError.wrap(error, at: input) }
    }
  }
}

extension ParserBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> ParserBuilder.ZipVVVVVV<P0, P1, P2, P3, P4, P5> {
    ParserBuilder.ZipVVVVVV(p0, p1, p2, p3, p4, p5)
  }
}

extension OneOfBuilder {
  public struct OneOf2<P0: Parser, P1: Parser>: Parser
  where
    P0.Input == P1.Input,
    P0.Output == P1.Output
  {
    public let p0: P0, p1: P1

    @inlinable public init(_ p0: P0, _ p1: P1) {
      self.p0 = p0
      self.p1 = p1
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P0.Output {
      let original = input
      do { return try self.p0.parse(&input) } catch let e0 {
        do {
          input = original
          return try self.p1.parse(&input)
        } catch let e1 {
          throw ParsingError.manyFailed(
            [e0, e1], at: input
          )
        }
      }
    }
  }
}

extension OneOfBuilder {
  @inlinable public static func buildBlock<P0, P1>(
    _ p0: P0, _ p1: P1
  ) -> OneOfBuilder.OneOf2<P0, P1> {
    OneOfBuilder.OneOf2(p0, p1)
  }
}

extension OneOfBuilder {
  public struct OneOf3<P0: Parser, P1: Parser, P2: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P0.Output == P1.Output,
    P1.Output == P2.Output
  {
    public let p0: P0, p1: P1, p2: P2

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P0.Output {
      let original = input
      do { return try self.p0.parse(&input) } catch let e0 {
        do {
          input = original
          return try self.p1.parse(&input)
        } catch let e1 {
          do {
            input = original
            return try self.p2.parse(&input)
          } catch let e2 {
            throw ParsingError.manyFailed(
              [e0, e1, e2], at: input
            )
          }
        }
      }
    }
  }
}

extension OneOfBuilder {
  @inlinable public static func buildBlock<P0, P1, P2>(
    _ p0: P0, _ p1: P1, _ p2: P2
  ) -> OneOfBuilder.OneOf3<P0, P1, P2> {
    OneOfBuilder.OneOf3(p0, p1, p2)
  }
}

extension OneOfBuilder {
  public struct OneOf4<P0: Parser, P1: Parser, P2: Parser, P3: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P0.Output == P1.Output,
    P1.Output == P2.Output,
    P2.Output == P3.Output
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P0.Output {
      let original = input
      do { return try self.p0.parse(&input) } catch let e0 {
        do {
          input = original
          return try self.p1.parse(&input)
        } catch let e1 {
          do {
            input = original
            return try self.p2.parse(&input)
          } catch let e2 {
            do {
              input = original
              return try self.p3.parse(&input)
            } catch let e3 {
              throw ParsingError.manyFailed(
                [e0, e1, e2, e3], at: input
              )
            }
          }
        }
      }
    }
  }
}

extension OneOfBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3
  ) -> OneOfBuilder.OneOf4<P0, P1, P2, P3> {
    OneOfBuilder.OneOf4(p0, p1, p2, p3)
  }
}

extension OneOfBuilder {
  public struct OneOf5<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser>: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P0.Output == P1.Output,
    P1.Output == P2.Output,
    P2.Output == P3.Output,
    P3.Output == P4.Output
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P0.Output {
      let original = input
      do { return try self.p0.parse(&input) } catch let e0 {
        do {
          input = original
          return try self.p1.parse(&input)
        } catch let e1 {
          do {
            input = original
            return try self.p2.parse(&input)
          } catch let e2 {
            do {
              input = original
              return try self.p3.parse(&input)
            } catch let e3 {
              do {
                input = original
                return try self.p4.parse(&input)
              } catch let e4 {
                throw ParsingError.manyFailed(
                  [e0, e1, e2, e3, e4], at: input
                )
              }
            }
          }
        }
      }
    }
  }
}

extension OneOfBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4
  ) -> OneOfBuilder.OneOf5<P0, P1, P2, P3, P4> {
    OneOfBuilder.OneOf5(p0, p1, p2, p3, p4)
  }
}

extension OneOfBuilder {
  public struct OneOf6<P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser>:
    Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P0.Output == P1.Output,
    P1.Output == P2.Output,
    P2.Output == P3.Output,
    P3.Output == P4.Output,
    P4.Output == P5.Output
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P0.Output {
      let original = input
      do { return try self.p0.parse(&input) } catch let e0 {
        do {
          input = original
          return try self.p1.parse(&input)
        } catch let e1 {
          do {
            input = original
            return try self.p2.parse(&input)
          } catch let e2 {
            do {
              input = original
              return try self.p3.parse(&input)
            } catch let e3 {
              do {
                input = original
                return try self.p4.parse(&input)
              } catch let e4 {
                do {
                  input = original
                  return try self.p5.parse(&input)
                } catch let e5 {
                  throw ParsingError.manyFailed(
                    [e0, e1, e2, e3, e4, e5], at: input
                  )
                }
              }
            }
          }
        }
      }
    }
  }
}

extension OneOfBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5
  ) -> OneOfBuilder.OneOf6<P0, P1, P2, P3, P4, P5> {
    OneOfBuilder.OneOf6(p0, p1, p2, p3, p4, p5)
  }
}

extension OneOfBuilder {
  public struct OneOf7<
    P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser, P6: Parser
  >: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P5.Input == P6.Input,
    P0.Output == P1.Output,
    P1.Output == P2.Output,
    P2.Output == P3.Output,
    P3.Output == P4.Output,
    P4.Output == P5.Output,
    P5.Output == P6.Output
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5, p6: P6

    @inlinable public init(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5, _ p6: P6) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
      self.p6 = p6
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P0.Output {
      let original = input
      do { return try self.p0.parse(&input) } catch let e0 {
        do {
          input = original
          return try self.p1.parse(&input)
        } catch let e1 {
          do {
            input = original
            return try self.p2.parse(&input)
          } catch let e2 {
            do {
              input = original
              return try self.p3.parse(&input)
            } catch let e3 {
              do {
                input = original
                return try self.p4.parse(&input)
              } catch let e4 {
                do {
                  input = original
                  return try self.p5.parse(&input)
                } catch let e5 {
                  do {
                    input = original
                    return try self.p6.parse(&input)
                  } catch let e6 {
                    throw ParsingError.manyFailed(
                      [e0, e1, e2, e3, e4, e5, e6], at: input
                    )
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

extension OneOfBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5, P6>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5, _ p6: P6
  ) -> OneOfBuilder.OneOf7<P0, P1, P2, P3, P4, P5, P6> {
    OneOfBuilder.OneOf7(p0, p1, p2, p3, p4, p5, p6)
  }
}

extension OneOfBuilder {
  public struct OneOf8<
    P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser, P6: Parser, P7: Parser
  >: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P5.Input == P6.Input,
    P6.Input == P7.Input,
    P0.Output == P1.Output,
    P1.Output == P2.Output,
    P2.Output == P3.Output,
    P3.Output == P4.Output,
    P4.Output == P5.Output,
    P5.Output == P6.Output,
    P6.Output == P7.Output
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5, p6: P6, p7: P7

    @inlinable public init(
      _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5, _ p6: P6, _ p7: P7
    ) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
      self.p6 = p6
      self.p7 = p7
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P0.Output {
      let original = input
      do { return try self.p0.parse(&input) } catch let e0 {
        do {
          input = original
          return try self.p1.parse(&input)
        } catch let e1 {
          do {
            input = original
            return try self.p2.parse(&input)
          } catch let e2 {
            do {
              input = original
              return try self.p3.parse(&input)
            } catch let e3 {
              do {
                input = original
                return try self.p4.parse(&input)
              } catch let e4 {
                do {
                  input = original
                  return try self.p5.parse(&input)
                } catch let e5 {
                  do {
                    input = original
                    return try self.p6.parse(&input)
                  } catch let e6 {
                    do {
                      input = original
                      return try self.p7.parse(&input)
                    } catch let e7 {
                      throw ParsingError.manyFailed(
                        [e0, e1, e2, e3, e4, e5, e6, e7], at: input
                      )
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

extension OneOfBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5, P6, P7>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5, _ p6: P6, _ p7: P7
  ) -> OneOfBuilder.OneOf8<P0, P1, P2, P3, P4, P5, P6, P7> {
    OneOfBuilder.OneOf8(p0, p1, p2, p3, p4, p5, p6, p7)
  }
}

extension OneOfBuilder {
  public struct OneOf9<
    P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser, P6: Parser, P7: Parser,
    P8: Parser
  >: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P5.Input == P6.Input,
    P6.Input == P7.Input,
    P7.Input == P8.Input,
    P0.Output == P1.Output,
    P1.Output == P2.Output,
    P2.Output == P3.Output,
    P3.Output == P4.Output,
    P4.Output == P5.Output,
    P5.Output == P6.Output,
    P6.Output == P7.Output,
    P7.Output == P8.Output
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5, p6: P6, p7: P7, p8: P8

    @inlinable public init(
      _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5, _ p6: P6, _ p7: P7, _ p8: P8
    ) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
      self.p6 = p6
      self.p7 = p7
      self.p8 = p8
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P0.Output {
      let original = input
      do { return try self.p0.parse(&input) } catch let e0 {
        do {
          input = original
          return try self.p1.parse(&input)
        } catch let e1 {
          do {
            input = original
            return try self.p2.parse(&input)
          } catch let e2 {
            do {
              input = original
              return try self.p3.parse(&input)
            } catch let e3 {
              do {
                input = original
                return try self.p4.parse(&input)
              } catch let e4 {
                do {
                  input = original
                  return try self.p5.parse(&input)
                } catch let e5 {
                  do {
                    input = original
                    return try self.p6.parse(&input)
                  } catch let e6 {
                    do {
                      input = original
                      return try self.p7.parse(&input)
                    } catch let e7 {
                      do {
                        input = original
                        return try self.p8.parse(&input)
                      } catch let e8 {
                        throw ParsingError.manyFailed(
                          [e0, e1, e2, e3, e4, e5, e6, e7, e8], at: input
                        )
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

extension OneOfBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5, P6, P7, P8>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5, _ p6: P6, _ p7: P7, _ p8: P8
  ) -> OneOfBuilder.OneOf9<P0, P1, P2, P3, P4, P5, P6, P7, P8> {
    OneOfBuilder.OneOf9(p0, p1, p2, p3, p4, p5, p6, p7, p8)
  }
}

extension OneOfBuilder {
  public struct OneOf10<
    P0: Parser, P1: Parser, P2: Parser, P3: Parser, P4: Parser, P5: Parser, P6: Parser, P7: Parser,
    P8: Parser, P9: Parser
  >: Parser
  where
    P0.Input == P1.Input,
    P1.Input == P2.Input,
    P2.Input == P3.Input,
    P3.Input == P4.Input,
    P4.Input == P5.Input,
    P5.Input == P6.Input,
    P6.Input == P7.Input,
    P7.Input == P8.Input,
    P8.Input == P9.Input,
    P0.Output == P1.Output,
    P1.Output == P2.Output,
    P2.Output == P3.Output,
    P3.Output == P4.Output,
    P4.Output == P5.Output,
    P5.Output == P6.Output,
    P6.Output == P7.Output,
    P7.Output == P8.Output,
    P8.Output == P9.Output
  {
    public let p0: P0, p1: P1, p2: P2, p3: P3, p4: P4, p5: P5, p6: P6, p7: P7, p8: P8, p9: P9

    @inlinable public init(
      _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5, _ p6: P6, _ p7: P7, _ p8: P8,
      _ p9: P9
    ) {
      self.p0 = p0
      self.p1 = p1
      self.p2 = p2
      self.p3 = p3
      self.p4 = p4
      self.p5 = p5
      self.p6 = p6
      self.p7 = p7
      self.p8 = p8
      self.p9 = p9
    }

    @inlinable public func parse(_ input: inout P0.Input) rethrows -> P0.Output {
      let original = input
      do { return try self.p0.parse(&input) } catch let e0 {
        do {
          input = original
          return try self.p1.parse(&input)
        } catch let e1 {
          do {
            input = original
            return try self.p2.parse(&input)
          } catch let e2 {
            do {
              input = original
              return try self.p3.parse(&input)
            } catch let e3 {
              do {
                input = original
                return try self.p4.parse(&input)
              } catch let e4 {
                do {
                  input = original
                  return try self.p5.parse(&input)
                } catch let e5 {
                  do {
                    input = original
                    return try self.p6.parse(&input)
                  } catch let e6 {
                    do {
                      input = original
                      return try self.p7.parse(&input)
                    } catch let e7 {
                      do {
                        input = original
                        return try self.p8.parse(&input)
                      } catch let e8 {
                        do {
                          input = original
                          return try self.p9.parse(&input)
                        } catch let e9 {
                          throw ParsingError.manyFailed(
                            [e0, e1, e2, e3, e4, e5, e6, e7, e8, e9], at: input
                          )
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

extension OneOfBuilder {
  @inlinable public static func buildBlock<P0, P1, P2, P3, P4, P5, P6, P7, P8, P9>(
    _ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5, _ p6: P6, _ p7: P7, _ p8: P8,
    _ p9: P9
  ) -> OneOfBuilder.OneOf10<P0, P1, P2, P3, P4, P5, P6, P7, P8, P9> {
    OneOfBuilder.OneOf10(p0, p1, p2, p3, p4, p5, p6, p7, p8, p9)
  }
}

// END AUTO-GENERATED CONTENT
