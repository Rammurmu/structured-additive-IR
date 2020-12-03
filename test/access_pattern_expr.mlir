// RUN: sair-opt -allow-unregistered-dialect %s -test-access-pattern-exprs | FileCheck %s

module {

// CHECK: "test.is_fully_specified"() {label = @none, result = false}
"test.is_fully_specified"() {label = @none, expr = #sair.pattern_expr<none>} : () -> ()

// CHECK: "test.is_fully_specified"() {label = @dim, result = true}
"test.is_fully_specified"() {label = @dim, expr = #sair.pattern_expr<d0>} : () -> ()

// CHECK: "test.is_fully_specified"() {label = @stripe_false, result = false}
"test.is_fully_specified"() {
  label = @stripe_false, expr = #sair.pattern_expr<stripe(none, 2)>
} : () -> ()

// CHECK: "test.is_fully_specified"() {label = @stripe_true, result = true}
"test.is_fully_specified"() {
  label = @stripe_true, expr = #sair.pattern_expr<stripe(d0, 2)>
} : () -> ()

// CHECK: "test.is_fully_specified"() {label = @unstripe_false, result = false}
"test.is_fully_specified"() {
  label = @unstripe_false, expr = #sair.pattern_expr<unstripe(none, [])>
} : () -> ()

// CHECK: "test.is_fully_specified"() {label = @unstripe_true, result = true}
"test.is_fully_specified"() {
  label = @unstripe_true, expr = #sair.pattern_expr<unstripe(d0, [])>
} : () -> ()

// CHECK: "test.min_domain_size"() {result = 3 : index}
"test.min_domain_size"() {
  expr = #sair.pattern_expr<unstripe(stripe(d2, 4), none, [2])>
} : () -> ()

// CHECK: "test.make_fully_specified"() {result = #sair.pattern_expr<unstripe(stripe(d1, 4), d0, d2, [4, 2])>}
"test.make_fully_specified"() {
  expr = #sair.pattern_expr<unstripe(stripe(none, 4), d0, none, [4, 2])>
} : () -> ()

// CHECK: "test.substitute_dims"() {result = #sair.pattern_expr<unstripe(stripe(d1, 4), none, [4])>}
"test.substitute_dims"() {
  expr = #sair.pattern_expr<unstripe(stripe(d0, 4), none, [4])>,
  substitutions = [#sair.pattern_expr<d1>]
} : () -> ()

// CHECK: "test.unify"() {label = @same_dim, result = #sair.pattern_expr<d0>}
"test.unify"() {
  label = @same_dim,
  expr = #sair.pattern_expr<d0>,
  other = #sair.pattern_expr<d0>
} : () -> ()

// CHECK: "test.unify"() {label = @none, result = #sair.pattern_expr<d0>}
"test.unify"() {
  label = @none,
  expr = #sair.pattern_expr<d0>,
  other = #sair.pattern_expr<none>
} : () -> ()

// CHECK: "test.unify"() {label = @different_dims, result}
"test.unify"() {
  label = @different_dims,
  expr = #sair.pattern_expr<d0>,
  other = #sair.pattern_expr<d1>
} : () -> ()

// CHECK: "test.unify"() {label = @stripe, result = #sair.pattern_expr<stripe(d0, 4)>}
"test.unify"() {
  label = @stripe,
  expr = #sair.pattern_expr<stripe(d0, 4)>,
  other = #sair.pattern_expr<stripe(none, 4)>
} : () -> ()

// CHECK: "test.unify"() {label = @stripe_different_factors, result}
"test.unify"() {
  label = @stripe_different_factors,
  expr = #sair.pattern_expr<stripe(d0, 4)>,
  other = #sair.pattern_expr<stripe(none, 8)>
} : () -> ()

// CHECK: "test.unify"() {label = @stripe_different_size, result}
"test.unify"() {
  label = @stripe_different_size,
  expr = #sair.pattern_expr<stripe(d0, 4 size 16)>,
  other = #sair.pattern_expr<stripe(none, 4 size 8)>
} : () -> ()

// CHECK: "test.unify"() {label = @unstripe_same_factors,
// CHECK-SAME: result = #sair.pattern_expr<unstripe(d0, d1, [4])>}
"test.unify"() {
  label = @unstripe_same_factors,
  expr = #sair.pattern_expr<unstripe(d0, none, [4])>,
  other = #sair.pattern_expr<unstripe(none, d1, [4])>
} : () -> ()


// CHECK: "test.unify"() {label = @unstripe_compatible_factors,
// CHECK-SAME: result = #sair.pattern_expr<unstripe(d0, none, d1, [4, 2])>}
"test.unify"() {
  label = @unstripe_compatible_factors,
  expr = #sair.pattern_expr<unstripe(d0, none, [4])>,
  other = #sair.pattern_expr<unstripe(none, d1, [2])>
} : () -> ()


// CHECK: "test.unify"() {label = @unstripe_incompatible_factors, result}
"test.unify"() {
  label = @unstripe_incompatible_factors,
  expr = #sair.pattern_expr<unstripe(d0, none, [4])>,
  other = #sair.pattern_expr<unstripe(none, d1, [8])>
} : () -> ()

// CHECK: "test.find_in_inverse"() {label = @stripe, result = #sair.pattern_expr<d2>}
"test.find_in_inverse"() {
  label = @stripe,
  expr = #sair.pattern_expr<stripe(d1, 1 size 4)>,
  inverse = #sair.pattern<3 : d0, unstripe(d1, d2, [4])>
} : () -> ()

// CHECK: "test.find_in_inverse"() {label = @unstripe, result = #sair.pattern_expr<d0>}
"test.find_in_inverse"() {
  label = @unstripe,
  expr = #sair.pattern_expr<unstripe(d0, d1, [4])>,
  inverse = #sair.pattern<1: stripe(d0, 4), stripe(d0, 1 size 4)>
} : () -> ()

// CHECK: "test.set_inverse"() {label = @dimension,
// CHECK-SAME: result = [#sair.pattern_expr<none>, #sair.pattern_expr<d0>]}
"test.set_inverse"() {
  label = @dimension,
  expr = #sair.pattern_expr<d1>,
  context = #sair.pattern_expr<d0>,
  inverses = [#sair.pattern_expr<none>, #sair.pattern_expr<none>]
} : () -> ()

// CHECK: "test.set_inverse"() {label = @none, result = []}
"test.set_inverse"() {
  label = @none,
  expr = #sair.pattern_expr<none>,
  context = #sair.pattern_expr<d0>,
  inverses = []
} : () -> ()

// CHECK: "test.set_inverse"() {label = @stripe,
// CHECK-SAME: result = [#sair.pattern_expr<unstripe(d0, none, [4])>]}
"test.set_inverse"() {
  label = @stripe,
  expr = #sair.pattern_expr<stripe(d0, 4)>,
  context = #sair.pattern_expr<d0>,
  inverses = [#sair.pattern_expr<none>]
} : () -> ()

// CHECK: "test.set_inverse"() {label = @unstripe,
// CHECK-SAME: result = [#sair.pattern_expr<stripe(d0, 4)>, #sair.pattern_expr<stripe(d0, 1 size 4)>]}
"test.set_inverse"() {
  label = @unstripe,
  expr = #sair.pattern_expr<unstripe(d0, d1, [4])>,
  context = #sair.pattern_expr<d0>,
  inverses = [#sair.pattern_expr<none>, #sair.pattern_expr<none>]
} : () -> ()

// CHECK: "test.unification_constraints"() {label = @valid
// CHECK-SAME: result = [#sair.pattern_expr<d2>, #sair.pattern_expr<none>]
"test.unification_constraints"() {
  label = @valid,
  expr = #sair.pattern_expr<unstripe(stripe(d0, 4), d1, none, [4, 2])>,
  other = #sair.pattern_expr<unstripe(stripe(d2, 4), none, d3, [4, 2])>,
  domain_size = 2
} : () -> ()

// CHECK: "test.unification_constraints"() {label = @invalid_factor_0, result}
"test.unification_constraints"() {
  label = @invalid_factor_0,
  expr = #sair.pattern_expr<unstripe(d0, d1, [4])>,
  other = #sair.pattern_expr<unstripe(d0, d1, [8])>,
  domain_size = 2
} : () -> ()

// CHECK: "test.unification_constraints"() {label = @invalid_factor_1, result}
"test.unification_constraints"() {
  label = @invalid_factor_1,
  expr = #sair.pattern_expr<unstripe(d0, d1, [8])>,
  other = #sair.pattern_expr<unstripe(d0, d1, [4])>,
  domain_size = 2
} : () -> ()

// CHECK: "test.unification_constraints"() {label = @invalid_inner, result}
"test.unification_constraints"() {
  label = @invalid_inner,
  expr = #sair.pattern_expr<unstripe(stripe(d0, 4), [])>,
  other = #sair.pattern_expr<unstripe(stripe(d0, 8), [])>,
  domain_size = 1
} : () -> ()

}
