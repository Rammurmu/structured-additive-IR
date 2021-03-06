// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifndef SAIR_SAIR_BASE_TD_
#define SAIR_SAIR_BASE_TD_

include "mlir/IR/OpBase.td"

def SairDialect : Dialect {
  let name = "sair";

  let summary = "Structured additive program representation";

  let description = [{
    Program representation designed to discover optimization opportunities early
    in the compilation process and to express implementation decisions without
    loosing the high-level structure of the code (hence the "additive" part of
    the name).
  }];

  let cppNamespace = "::sair";
}

//===----------------------------------------------------------------------===//
// Sair Attributes
//===----------------------------------------------------------------------===//

def MappingExpr : AttrInterface<"MappingExpr"> {
  let description = [{
    Interface class for mapping expressions. Mapping expressions
    specify how to access a dimension of another domain given the index along
    dimensions of the current domain.
  }];

  let methods = [
    InterfaceMethod<
      "Indicates if the expression does not contain `none`",
      "bool", "IsFullySpecified"
    >,
    InterfaceMethod<
      [{Replaces occurences of `none` by freshly allocated dimensions. Starts
        allocating at `num_dimensions` and increase it each time a new dimension
        is allocated.}],
      "MappingExpr", "MakeFullySpecified", (ins "int&":$num_dimensions)
    >,
    InterfaceMethod<
      "Sets the dimensions referenced by the expression in `mask`",
      "void", "SetDependenciesInMask", (ins "llvm::SmallBitVector&":$mask)
    >,
    InterfaceMethod<
      "Returns a mask of the dimensions referenced by the expression.",
      "llvm::SmallBitVector", "DependencyMask", (ins "int":$domain_size), [{
        llvm::SmallBitVector mask(domain_size);
        $_attr.SetDependenciesInMask(mask);
        return mask;
      }]
    >,
    InterfaceMethod<
      "Returns the minimal domain size for the expression to be valid.",
      "int", "MinDomainSize"
    >,
    InterfaceMethod<
      "Substitutes dimension expressions by the given expressions",
      "MappingExpr", "SubstituteDims",
      (ins "mlir::ArrayRef<MappingExpr>":$exprs)
    >,
    InterfaceMethod<
      [{Returns the shape of the dimension accessed by the given expression.
        `accessing_shape` must be the shape of the current domain and
        `inverted_mapping` the inverse of the full mapping.}],
      "DomainShapeDim", "AccessedShape", (ins
        "llvm::ArrayRef<DomainShapeDim>":$accessing_shape,
        "MappingAttr":$inversed_mapping
      )
    >,
    InterfaceMethod<
      [{Sets `inverses[i]` to the inverse of the current expression (and its
      context) with regard to the i-th dimension of the domain. `inverses` size
      must be equal to the size of the domain.

      `context_inverse` is the inverse of the surrounding sub-expression. If
      the current sub-expression is `e` in `C(e)`, then `context_inverse` is
      the inverse of `C(x)`.

      Returns a failure if the inverse of this expression cannot be unified
      with inverses already set in `inverses`.}],
      "mlir::LogicalResult", "SetInverse", (ins
        "MappingExpr":$context_inverse,
        "llvm::MutableArrayRef<MappingExpr>":$inverses
      )
    >,
    InterfaceMethod<
      [{Finds the subexpression corresponding to the inverse of this expression
        in `inverse`. Expects the expression to be fully specified. `inverse`
        must be the inverse of the mapping using this sub-expression.}],
      "MappingExpr", "FindInInverse",
      (ins "llvm::ArrayRef<MappingExpr>":$inverse)
    >,
    InterfaceMethod<
      [{Unifies two expressions by replacing the `none` of each expr by the
        corresponding sub-expression of the other expr. Returns nullptr if
        expressions cannot be unified.}],
      "MappingExpr", "Unify", (ins "MappingExpr":$other_expr)
    >,
    InterfaceMethod<
      [{Fills `constraints` with expression such that
        `this.SubstituteDims(constraints).Unify(other_expr)` is valid. Expects
        `contraints` to be initially filled with `none`. Leaves `constraints[i]`
        untouched if dimension i generates no constraints. Returns a failure if
        expressions cannot be unified.}],
      "mlir::LogicalResult", "UnificationConstraints", (ins
        "MappingExpr":$other_expr,
        "llvm::MutableArrayRef<MappingExpr>":$constraints
      )
    >,
    InterfaceMethod<
      [{Converts the expression into an affine expression. The expression must
        be fully specified}],
      "mlir::AffineExpr", "AsAffineExpr"
    >,
    InterfaceMethod<
      [{Canonicalizes the expression.}], "MappingExpr", "Canonicalize"
    >,
    InterfaceMethod<
      [{Returns the parameters (start index, end index and step) of the range
        represented by the expression. Adds operations to compute the parameters
        to the body of a sair.map operation at the insertion point pointed to by
        `builder` and adds arguments to the sair.map if necessary using
        `map_arguments`.

        After returning, builder insertion point is after newly added
        instructions.}],
      "RangeParameters", "GetRangeParameters",
      (ins "mlir::Location":$loc, "mlir::ValueRange":$domain,
           "DomainShapeAttr":$shape, "MappingAttr":$inverse_mapping,
           "mlir::OpBuilder&":$builder, "MapArguments&":$map_arguments)
    >
  ];
}

// Tests if an attribute is an MappingAttr.
def IsSairMappingAttr : CPred<"$_self.isa<MappingAttr>()">;

// Specifies how a Sair value is accessed in the domain of another operation.
def SairMappingAttr : Attr<IsSairMappingAttr, "mapping"> {
  let storageType = [{MappingAttr}];
  let returnType = storageType;
}

// Tests if an attribute is a DomainShapeAttr.
def IsSairDomainShapeAttr : CPred<"$_self.isa<DomainShapeAttr>()">;

// Specifies the shape of a Sair iteration domain.
def SairDomainShapeAttr : Attr<IsSairDomainShapeAttr, "domain shape"> {
  let storageType = [{DomainShapeAttr}];
  let returnType = storageType;
}

// Derived attribute that returns a domain shape with 0 dimensions.
def SairEmptyDomainShapeAttr :
  DerivedAttr<"DomainShapeAttr",
              [{return DomainShapeAttr::get(getContext());}]> {
  let convertFromStorage = [{$_self}];
}

// Derived attribute that returns the shape of results.
def SairResultDomainShapeAttr :
    DerivedAttr<"DomainShapeAttr", [{
      mlir::Type type = getOperation()->getResult(0).getType();
      return type.cast<SairShapedType>().Shape();
    }]> {
  let convertFromStorage = [{$_self}];
}

// Tests if an attribute is an MappingExpr.
def IsSairMappingExpr : CPred<"$_self.isa<sair::MappingExpr>()">;

// Defines an iterator on a dimension of the domain of the current operation.
def SairMappingExpr : Attr<IsSairMappingExpr, "mapping_expr"> {
  let storageType = [{MappingExpr}];
  let returnType = storageType;
}

// Helper to define a struct attribute with some additional constraints. The
// attribute passed to constraints has the struct type.
class SairStructAttr<string name,
                     list<StructFieldAttr> fields,
                     list<AttrConstraint> constraints = []>
  : Confined<
      StructAttr<name, SairDialect, fields>,
      !foreach(c, constraints, AttrConstraint<
        SubstLeaves<"$_self", "$_self.cast<" # name # ">()", c.predicate>,
        c.summary>
      )>;

// An attribute describing a loop to generate when lowering an operation.
def SairLoopAttr : SairStructAttr<"LoopAttr", [
  // Name of the loop to generate.
  StructFieldAttr<"name", StrAttr>,
  StructFieldAttr<"iter", SairMappingExpr>
]>;

// A loop nest to generate when lowering an operation.
def SairLoopNestAttr
  : OptionalAttr<TypedArrayAttrBase<SairLoopAttr, "array of LoopAttr">>;

// An attribute holding the memory space of operations results.
def SairMemorySpaceAttr
  : OptionalAttr<TypedArrayAttrBase<
      Attr<
        CPred<"$_self.isa<UnitAttr>() || $_self.isa<IntegerAttr>()">,
        "memory space">,
      "array of memory space">>;

//===----------------------------------------------------------------------===//
// Sair Types
//===----------------------------------------------------------------------===//

// Type constraint for ranges.
def SairRange : Type<CPred<"$_self.isa<RangeType>()">, "range">;

// Type constraint for Sair values.
def SairValue : Type<CPred<"$_self.isa<ValueType>()">, "value">;

// Predicate that checks the element type of a Sair value.
class SairElementTypePred<Type type>
  : SubstLeaves<"$_self", "$_self.cast<ValueType>().ElementType()",
    type.predicate>;

// Type constraint for Sair values with a specific element type.
class SairValueOf<Type type>
  : Type<And<[SairValue.predicate, SairElementTypePred<type>]>,
      "sair.value with " # type.summary # " elements">;

// Type for arrays of mappings.
def SairMappingArrayAttr :
  TypedArrayAttrBase<SairMappingAttr, "mappings array">;

//===----------------------------------------------------------------------===//
// Sair Traits
//===----------------------------------------------------------------------===//

// Ensures that two named values have the same element type. Values can be Sair
// values or mlir shaped values.
class SairSameElementType<string lhs, string rhs>
  : PredOpTrait<lhs # " and " # rhs # " have the same element type",
      CPred<"IsSameElementType(" # lhs # "(), " # rhs # "())">>;

//===----------------------------------------------------------------------===//
// Sair Interfaces
//===----------------------------------------------------------------------===//

def SairOpInterface : OpInterface<"SairOp"> {
  let description = [{
    Common interface for Sair operations, that requires them to expose their
    iteration domain.

    The operation must have an "mapping_attr" attribute unless
    ValueOperands returns an empty range.
  }];

  let methods = [
    InterfaceMethod<
      "Returns the shape of the iteration domain of the operation",
      "DomainShapeAttr", "shape"
    >,
    InterfaceMethod<
      "Returns the dimensions that compose the domain of the operation",
      "mlir::Operation::operand_range", "domain", (ins), [{}], [{
        return mlir::OperandRange(nullptr, 0);
      }]
    >,
    InterfaceMethod<
      "Returns the number of dimensions in the domains of produced Sair values",
      "int", "results_rank", (ins), [{}], [{
        return cast<ConcreteOp>(this->getOperation()).shape().NumDimensions();
      }]
    >,
    InterfaceMethod<
      "Returns the mappings for the !sair.value operands",
      "mlir::ArrayAttr", "mapping_array", (ins), [{}], [{
        return mlir::ArrayAttr::get({}, this->getOperation()->getContext());
      }]
    >,
    InterfaceMethod<
      "Sets the mapping for the given Sair value operand",
      "void", "SetMapping",
      (ins "int":$position, "MappingAttr":$mapping), [{}], [{
        ::sair::SetMapping(ConcreteOp($_op), position, mapping);
      }]
    >,
    InterfaceMethod<
      "Returns the Sair values accessed by the operation",
      "ValueOperandRange", "ValueOperands", (ins), [{}], [{
        return ::sair::ValueOperands(ConcreteOp($_op));
      }]
    >,
    InterfaceMethod<
      [{Returns a mask of the dimensions of the current operation that depend on
        `sair_operand`. The operand must be executed before entering these
        dimensions.}],
      "llvm::SmallBitVector", "DimsDependingOnOperand",
      (ins "int":$sair_operand), [{}], [{
        int size = cast<ConcreteOp>(this->getOperation()).domain().size();
        return llvm::SmallBitVector(size);
      }]
    >,
    InterfaceMethod<
      [{Returns the dimensions that must finish before using results}],
      "llvm::SmallBitVector", "ResultsDimDependencies",
      (ins), [{}], [{
        int size = cast<ConcreteOp>(this->getOperation()).domain().size();
        return llvm::SmallBitVector(size);
      }]
    >,
    InterfaceMethod<
      [{Indicates a Sair operand can be definied after this operation}],
      "bool", "AllowUseBeforeDef", (ins "int":$sair_operand), [{}],
      [{return false;}]
    >,
    InterfaceMethod<
      [{Returns a mask of the dimensions of the current operation that carry
        dependencies accross iterations for the given !sair.value operand}],
      "llvm::SmallBitVector", "CarryingDimensions",
      (ins "int":$sair_operand), [{}], [{
        int size = cast<ConcreteOp>(this->getOperation()).domain().size();
        return llvm::SmallBitVector(size);
      }]
    >,
    InterfaceMethod<
      [{Creates a copy of the operation with a new domain. May steal the body of
        the current operation but does not erase it.}],
      "SairOp", "ReCreateWithNewDomain", (ins
        "llvm::ArrayRef<llvm::SmallVector<mlir::Value, 4>>":$new_domains,
        "DomainShapeAttr":$new_shape,
        "MappingAttr":$new_to_old_mapping,
        "mlir::OpBuilder &":$builder
      )
    >,
    InterfaceMethod<
      [{Indicates the size of each sub-domain. The first sub-domain is always
        the parallel domain}],
      "llvm::SmallVector<int, 2>", "SubDomains", (ins), [{}]
    >
  ];

  let verify = [{return VerifySairOp(op);}];
}

// Base class for all Sair operators.
class SairOp<string mnemonic,
             list<OpTrait> traits = [],
             Dialect dialect = SairDialect>
  : Op<
      dialect, mnemonic,
      !listconcat([
        SairOpInterface,
        DeclareOpInterfaceMethods<SairOpInterface>
      ], traits)
    > {

  let hasCanonicalizer = 1;
}

def SairOpWithBody : OpInterface<"SairOpWithBody"> {
  let description = [{
    Interface for Sair operations that execute a region for all the points of
    their domain.
  }];

  let methods = [
    InterfaceMethod<
      "Returns the block executed at each point of the operation domain",
      "mlir::Block&", "block", (ins), [{}], [{
        return this->getOperation()->getRegions()[0].front();
      }]
    >,
  ];
}

def SairValueProducerOp : OpInterface<"ValueProducerOp"> {
  let description = [{
    A Sair operation that produces variables of type !sair.value. All operations
    producing Sair values should implement this interface, and they should only
    produce Sair values.

    Assumes that the operation has an optional SairMemorySpaceAttr attribute.
    This attribte is an array of integers that indicates the memory space of
    each !sair.value variable produced. It containts `UnitAttr` for results
    whose memory space is not set. Possible values are `kRegister` (`=0`) and
    `kMemory` (`=1`).
  }];

  let methods = [
    InterfaceMethod<
      "Returns the array assigning a memory space to each result",
      "Optional<mlir::ArrayAttr>", "memory_space"
    >,
    InterfaceMethod<
      "Indicates if the memory space of the given result is set.",
      "bool", "IsMemorySpaceSet", (ins "int":$result), [{}],
      [{return sair::GetMemorySpace(result, this->getOperation()).hasValue();}]
    >,
    InterfaceMethod<
      "Returns the memory space of the given result.",
      "llvm::Optional<int>", "GetMemorySpace", (ins "int":$result), [{}],
      [{return sair::GetMemorySpace(result, this->getOperation());}]
    >,
    InterfaceMethod<
      "Sets the memory space of the given result.", "void", "SetMemorySpace",
      (ins "int":$result, "llvm::Optional<int>":$memory_space), [{}],
      [{sair::SetMemorySpace(result, memory_space, this->getOperation());}]
    >,
  ];

  let verify = [{return sair::VerifyValueProducerOp(op);}];

  // TODO(ulysse): use a machine description instead of fixed memory spaces.
  let extraClassDeclaration = [{
    static constexpr int kRegister = 0;
    static constexpr int kMemory = 1;

    static constexpr llvm::StringRef kMemorySpaceAttrName = "memory_space";
  }];
}

def SairComputeOp : OpInterface<"ComputeOp"> {
  let description = [{
    A Sair operation that performs a computation and results in actual code.
    This is as oppposition to operations defining iteration dimensions and
    casting sair to/from Sair values.

    Assumes that the operation has an optional `loop_nest` attribute of type
    `SairLoopNestAttr`. Checks dimension names are only used once in the loop
    nest, that dimensions referenced by the loop nest are dimensions of the
    domain, and that the loop nest iterates on the full domain.
  }];

  let methods = [
    InterfaceMethod<
      "Returns the loop nest to generate when lowering the operation",
      "Optional<mlir::ArrayAttr>", "loop_nest"
    >,
    InterfaceMethod<
      "Sets the loop nest to generate when lowering the operation",
      "void", "setLoopNest", (ins "mlir::ArrayAttr":$loop_nest), [{
        $_op.loop_nestAttr(loop_nest);
      }]
    >,
    InterfaceMethod<
      "Returns the loops in the loop_nest attribute. Fails if it is missing.",
      "llvm::ArrayRef<mlir::Attribute>", "LoopNestLoops", (ins), [{}], [{
        return $_op.loop_nest().getValue().getValue();
      }]
    >
  ];

  let extraClassDeclaration = [{
    static constexpr llvm::StringRef kLoopNestAttrName = "loop_nest";
  }];
}

def SairInferIterationSpaceOp : OpInterface<"InferIterationSpaceOp"> {
  let description = [{
    A Sair operation whose loop nest is infered from the loop nest of an
    operand.
  }];

  let methods = [
    InterfaceMethod<
      "Position of the Sair value operand to inherit the iteration space from.",
      "int", "infer_iteration_space_operand"
    >
  ];
}

def SairRangeOp : OpInterface<"RangeOp"> {
  let description = [{A Sair operation that defines a !sair.range}];

  let methods = [
    InterfaceMethod<"Returns the range step", "llvm::APInt", "step">,
    InterfaceMethod<
      "Returns the upper bound of the range", "ValueOrConstant", "LowerBound"
    >,
    InterfaceMethod<
      "Returns the lower bound of the range", "ValueOrConstant", "UpperBound"
    >,
  ];

  let extraClassDeclaration = [{
    static constexpr llvm::StringRef kStepAttrName = "step";
  }];

  let verify = [{return sair::VerifyRangeOp(op);}];
}

#endif  // SAIR_SAIR_BASE_TD_
