// RUN: sair-opt %s -sair-lower-to-map --mlir-print-local-scope | FileCheck %s
// RUN: sair-opt %s -sair-lower-to-map --mlir-print-op-generic | FileCheck %s --check-prefix=GENERIC

// CHECK-LABEL: @copy
func @copy(%arg0 : memref<?x?xf32>) {
  sair.program {
    // CHECK: %[[V0:.*]] = sair.static_range
    %0 = sair.static_range 8 : !sair.range
    %1 = sair.from_scalar %arg0 : !sair.value<(), memref<?x?xf32>>
    // CHECK: %[[V1:.*]] = sair.from_memref
    %2 = sair.from_memref %1 memref[d0:%0, d1:%0]
      : #sair.shape<d0:range x d1:range>, memref<?x?xf32>
    // CHECK: sair.map[d0:%[[V0]], d1:%[[V0]]] %[[V1]](d1, d0) {
    // CHECK: ^{{.*}}(%{{.*}}: index, %{{.*}}: index, %[[ARG0:.*]]: f32):
    // CHECK: sair.return %[[ARG0]] : f32
    %3 = sair.copy[d0:%0, d1:%0] %2(d1, d0)
    // CHECK: } : #sair.shape<d0:range x d1:range>, (f32) -> f32
      : !sair.value<d0:range x d1:range, f32>
    sair.exit
  }
  return
}

// CHECK-LABEL: @map_reduce
func @map_reduce(%r1: index, %r2: index, %in1: f32) {
  sair.program {
    %0 = sair.from_scalar %r1 : !sair.value<(), index>
    %1 = sair.from_scalar %r2 : !sair.value<(), index>
    // CHECK: %[[RANGE1:.*]] = sair.dyn_range
    %2 = sair.dyn_range %0 : !sair.range
    // CHECK: %[[RANGE2:.*]] = sair.dyn_range
    %3 = sair.dyn_range %1 : !sair.range

    %4 = sair.from_scalar %in1 : !sair.value<(), f32>
    %5 = sair.copy[d0:%2, d1:%3] %4 : !sair.value<d0:range x d1:range, f32>
    %6 = sair.copy[d0:%2] %4 : !sair.value<d0:range, f32>
    %7 = sair.copy[d0:%2] %4 : !sair.value<d0:range, f32>

    // CHECK: %[[FBY1:.*]] = sair.fby[d0:%[[RANGE1]]] %[[INIT1:.*]] then[d1:%[[RANGE2]]] %[[OUTPUT:.*]]#0(d0, d1)
    // CHECK: %[[FBY2:.*]] = sair.fby[d0:%[[RANGE1]]] %[[INIT2:.*]] then[d1:%[[RANGE2]]] %[[OUTPUT]]#1(d0, d1)
    // CHECK: %[[OUTPUT]]:2 = sair.map[d0:%[[RANGE1]], d1:%[[RANGE2]]] %[[FBY1]](d0, d1), %[[FBY2]](d0, d1), %{{.*}}
    %8:2 = sair.map_reduce[d0:%2] %6(d0), %7(d0) reduce[d1:%3] %5(d0, d1) {
    // CHECK: ^{{.*}}
    ^bb0(%arg0: index, %arg1: index, %arg2: f32, %arg3: f32, %arg4: f32):
      // CHECK: addf
      %9 = addf %arg2, %arg3 : f32
      // CHECK: mulf
      %10 = mulf %arg2, %arg3 : f32
      sair.return %9, %10 : f32, f32
    // CHECK: #sair.shape<d0:range x d1:range>, (f32, f32, f32) -> (f32, f32)
    } : #sair.shape<d0:range x d1:range>, (f32) -> (f32, f32)
    // Verify the result types have correct shapes.
    // GENERIC: "sair.map"
    // GENERIC:      (!sair.range, !sair.range, !sair.value<d0:range x d1:range, f32>,
    // GENERIC-SAME:  !sair.value<d0:range x d1:range, f32>, !sair.value<d0:range x d1:range, f32>) ->
    // GENERIC-SAME: (!sair.value<d0:range x d1:range, f32>, !sair.value<d0:range x d1:range, f32>)

    // CHECK: sair.proj_last[d0:%[[RANGE1]]] of[d1:%[[RANGE2]]] %[[OUTPUT]]#0(d0, d1)
    // CHECK: sair.proj_last[d0:%[[RANGE1]]] of[d1:%[[RANGE2]]] %[[OUTPUT]]#1(d0, d1)
    // GENERIC: "sair.proj_last"
    sair.exit
  }
  return
}

// CHECK-LABEL: @alloc
func @alloc(%arg0: index) {
  sair.program {
    // CHECK: %[[D0:.*]] = sair.static_range
    %0 = sair.static_range 2 : !sair.range
    // CHECK: %[[D1:.*]] = sair.static_range
    %1 = sair.static_range 3 : !sair.range
    %idx = sair.from_scalar %arg0 : !sair.value<(), index>
    // CHECK: %[[SZ0:.*]] = sair.map
    %2 = sair.copy[d0:%0] %idx : !sair.value<d0:range, index>
    // CHECK: %[[SZ1:.*]] = sair.map
    %3 = sair.copy[d0:%1] %idx : !sair.value<d0:range, index>
    // CHECK: sair.map[d0:%[[D0]], d1:%[[D1]]] %[[SZ0]](d0), %[[SZ1]](d1) {
    // CHECK: ^{{.*}}(%{{.*}}: index, %{{.*}}: index, %[[ARG2:.*]]: index, %[[ARG3:.*]]: index):
    // CHECK:   %[[ALLOC:.*]] = alloc(%[[ARG2]], %[[ARG3]]) : memref<?x?xf32>
    // CHECK:   sair.return %[[ALLOC]]
    // CHECK: } : #sair.shape<d0:range x d1:range>, (index, index) -> memref<?x?xf32>
    sair.alloc[d0:%0, d1:%1] %2(d0), %3(d1) : !sair.value<d0:range x d1:range, memref<?x?xf32>>
    sair.exit
  }
  return
}

// CHECK-LABEL: @sair_free
func @sair_free(%arg0: index) {
  sair.program {
    // CHECK: %[[D0:.*]] = sair.static_range
    %0 = sair.static_range 2 : !sair.range
    // CHECK: %[[D1:.*]] = sair.static_range
    %1 = sair.static_range 3 : !sair.range
    %idx = sair.from_scalar %arg0 : !sair.value<(), index>
    // CHECK: sair.map
    %2 = sair.copy[d0:%0] %idx : !sair.value<d0:range, index>
    // CHECK: sair.map
    %3 = sair.copy[d0:%1] %idx : !sair.value<d0:range, index>
    // CHECK: %[[ALLOC:.*]] = sair.map
    %4 = sair.alloc[d0:%0, d1:%1] %2(d0), %3(d1) : !sair.value<d0:range x d1:range, memref<?x?xf32>>
    // CHECK: sair.map[d0:%[[D1]], d1:%[[D0]]] %[[ALLOC]](d1, d0) {
    // CHECK: ^{{.*}}(%{{.*}}: index, %{{.*}}: index, %[[ARG2:.*]]: memref<?x?xf32>):
    // CHECK:   dealloc %[[ARG2]] : memref<?x?xf32>
    // CHECK:   sair.return
    // CHECK: } : #sair.shape<d0:range x d1:range>, (memref<?x?xf32>) -> ()
    sair.free[d0:%1, d1:%0] %4(d1, d0) : !sair.value<d0:range x d1:range, memref<?x?xf32>>
    sair.exit
  }
  return
}

// CHECK-LABEL: @load_from_memref
func @load_from_memref(%arg0 : memref<?x?xf32>) {
  sair.program {
    %0 = sair.static_range 8 : !sair.range
    %1 = sair.from_scalar %arg0 : !sair.value<(), memref<?x?xf32>>
    // CHECK: = sair.map[d0:%{{.*}}, d1:%{{.*}}, d2:%{{.*}}] %{{.*}} {
    // CHECK: ^{{.*}}(%[[ARG1:.*]]: index, %[[ARG2:.*]]: index, %[[ARG3:.*]]: index, %[[MEMREF:.*]]: memref<?x?xf32>):
    // CHECK:   %[[VALUE:.*]] = load %[[MEMREF]][%[[ARG2]], %[[ARG3]]] : memref<?x?xf32>
    // CHECK:   sair.return %[[VALUE]] : f32
    // CHECK: } : #sair.shape<d0:range x d1:range x d2:range>, (memref<?x?xf32>) -> f32
    %2 = sair.load_from_memref[d0:%0] %1 memref[d1:%0, d2:%0]
      : #sair.shape<d0:range x d1:range x d2:range>, memref<?x?xf32>
    sair.exit
  }
  return
}

// CHECK-LABEL: @load_from_memref_permuted
func @load_from_memref_permuted(%arg0 : memref<?x?xf32>) {
  sair.program {
    %0 = sair.static_range 8 : !sair.range
    %1 = sair.from_scalar %arg0 : !sair.value<(), memref<?x?xf32>>
    // CHECK: sair.map
    %2 = sair.copy[d0:%0] %1 : !sair.value<d0:range, memref<?x?xf32>>

    // CHECK: = sair.map[d0:%{{.*}}, d1:%{{.*}}, d2:%{{.*}}] %{{.*}}(d0) attributes {foo = "bar"} {
    // CHECK: ^{{.*}}(%[[ARG1:.*]]: index, %[[ARG2:.*]]: index, %[[ARG3:.*]]: index, %[[MEMREF:.*]]: memref<?x?xf32>):
    // CHECK:   %[[IDX1:.*]] = affine.apply affine_map<(d0, d1) -> (d1)>(%[[ARG2]], %[[ARG3]])
    // CHECK:   %[[IDX2:.*]] = affine.apply affine_map<(d0, d1) -> (d0)>(%[[ARG2]], %[[ARG3]])
    // CHECK:   %[[VALUE:.*]] = load %[[MEMREF]][%[[IDX1]], %[[IDX2]]] : memref<?x?xf32>
    // CHECK:   sair.return %[[VALUE]] : f32
    // CHECK: } : #sair.shape<d0:range x d1:range x d2:range>, (memref<?x?xf32>) -> f32
    %3 = sair.load_from_memref[d0:%0] %2(d0) memref[d1:%0, d2:%0]
      {access_map = affine_map<(d0,d1)->(d1,d0)>, foo = "bar"}
      : #sair.shape<d0:range x d1:range x d2:range>, memref<?x?xf32>
    sair.exit
  }
  return
}

// CHECK-LABEL: @store_to_memref
func @store_to_memref(%arg0 : f32, %arg1 : memref<?x?xf32>) {
  sair.program {
    %0 = sair.static_range 8 : !sair.range
    %1 = sair.from_scalar %arg0 : !sair.value<(), f32>
    %2 = sair.from_scalar %arg1 : !sair.value<(), memref<?x?xf32>>
    // CHECK: sair.map
    %3 = sair.copy[d0:%0, d1:%0, d2:%0] %1
      : !sair.value<d0:range x d1:range x d2:range, f32>

    // CHECK: sair.map[d0:%{{.*}}, d1:%{{.*}}, d2:%{{.*}}] %{{.*}}, %{{.*}}(d0, d1, d2) {
    // CHECK: ^{{.*}}(%[[ARG1:.*]]: index, %[[ARG2:.*]]: index, %[[ARG3:.*]]: index, %[[MEMREF:.*]]: memref<?x?xf32>, %[[VALUE:.*]]: f32):
    // CHECK:   store %[[VALUE]], %[[MEMREF]][%[[ARG2]], %[[ARG3]]]
    // CHECK:   sair.return
    // CHECK: } : #sair.shape<d0:range x d1:range x d2:range>, (memref<?x?xf32>, f32) -> ()
    sair.store_to_memref[d0:%0] %2 memref[d1:%0, d2:%0] %3(d0, d1, d2)
      : #sair.shape<d0:range x d1:range x d2:range>, memref<?x?xf32>
    sair.exit
  }
  return
}

// CHECK-LABEL: @store_to_memref_permuted
func @store_to_memref_permuted(%arg0 : f32, %arg1 : memref<?x?xf32>) {
  sair.program {
    %0 = sair.static_range 8 : !sair.range
    %1 = sair.from_scalar %arg0 : !sair.value<(), f32>
    %2 = sair.from_scalar %arg1 : !sair.value<(), memref<?x?xf32>>
    // CHECK: sair.map
    %3 = sair.copy[d0:%0, d1:%0, d2:%0] %1
      : !sair.value<d0:range x d1:range x d2:range, f32>

    // CHECK: sair.map
    %4 = sair.copy[d0:%0] %2 : !sair.value<d0:range, memref<?x?xf32>>

    // CHECK: sair.map[d0:%{{.*}}, d1:%{{.*}}, d2:%{{.*}}] %{{.*}}(d0), %{{.*}}(d0, d1, d2) attributes {foo = "bar"} {
    // CHECK: ^{{.*}}(%[[ARG1:.*]]: index, %[[ARG2:.*]]: index, %[[ARG3:.*]]: index, %[[MEMREF:.*]]: memref<?x?xf32>, %[[VALUE:.*]]: f32):
    // CHECK:   %[[IDX1:.*]] = affine.apply affine_map<(d0, d1) -> (d1)>(%[[ARG2]], %[[ARG3]])
    // CHECK:   %[[IDX2:.*]] = affine.apply affine_map<(d0, d1) -> (d0)>(%[[ARG2]], %[[ARG3]])
    // CHECK:   store %[[VALUE]], %[[MEMREF]][%[[IDX1]], %[[IDX2]]]
    // CHECK:   sair.return
    // CHECK: } : #sair.shape<d0:range x d1:range x d2:range>, (memref<?x?xf32>, f32) -> ()
    sair.store_to_memref[d0:%0] %4(d0) memref[d1:%0, d2:%0] %3(d0, d1, d2)
      {access_map = affine_map<(d0,d1)->(d1,d0)>, foo = "bar"}
      : #sair.shape<d0:range x d1:range x d2:range>, memref<?x?xf32>
    sair.exit
  }
  return
}
