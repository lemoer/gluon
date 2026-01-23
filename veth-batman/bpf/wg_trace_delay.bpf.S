; ModuleID = '<stdin>'
source_filename = "/home/lemoer/git/ff/veth-batman/openwrt/net/wg-trace-delay-c/../../../bpf/wg_trace_delay.bpf.c"
target datalayout = "E-m:m-p:32:32-i8:8:32-i16:16:32-i64:64-n32-S64"
target triple = "bpfeb"

%struct.anon = type { ptr, ptr, ptr, ptr }
%struct.anon.0 = type { ptr, ptr }
%struct.anon.1 = type { ptr, ptr, ptr, ptr }

@LICENSE = dso_local global [4 x i8] c"GPL\00", section "license", align 1, !dbg !0
@start_ts = dso_local global %struct.anon zeroinitializer, section ".maps", align 4, !dbg !19
@events = dso_local global %struct.anon.0 zeroinitializer, section ".maps", align 4, !dbg !37
@last_emit_ts = dso_local global %struct.anon.1 zeroinitializer, section ".maps", align 4, !dbg !51
@llvm.compiler.used = appending global [6 x ptr] [ptr @LICENSE, ptr @events, ptr @last_emit_ts, ptr @start_ts, ptr @trace_wg_end, ptr @trace_wg_start], section "llvm.metadata"

; Function Attrs: nounwind
define dso_local noundef i32 @trace_wg_start(ptr nocapture noundef readonly %0) #0 section "kprobe/wg_prev_queue_enqueue" !dbg !109 {
  %2 = alloca i64, align 8
  %3 = alloca i64, align 8
    #dbg_value(ptr %0, !136, !DIExpression(), !141)
  %4 = getelementptr inbounds nuw i8, ptr %0, i32 52, !dbg !142
  %5 = load i32, ptr %4, align 4, !dbg !142, !tbaa !143
    #dbg_value(i32 %5, !137, !DIExpression(), !141)
    #dbg_value(i32 undef, !138, !DIExpression(DW_OP_LLVM_convert, 32, DW_ATE_unsigned, DW_OP_LLVM_convert, 64, DW_ATE_unsigned, DW_OP_stack_value), !141)
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %2) #2, !dbg !147
    #dbg_value(i64 0, !139, !DIExpression(), !141)
  store i64 0, ptr %2, align 8, !dbg !148, !tbaa !149
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %3) #2, !dbg !151
  %6 = tail call i64 inttoptr (i32 5 to ptr)() #2, !dbg !152
    #dbg_value(i64 %6, !140, !DIExpression(), !141)
  store i64 %6, ptr %3, align 8, !dbg !153, !tbaa !149
  %.not = icmp eq i32 %5, 0, !dbg !154
  br i1 %.not, label %9, label %7, !dbg !156

7:                                                ; preds = %1
    #dbg_value(ptr %2, !139, !DIExpression(DW_OP_deref), !141)
    #dbg_value(ptr %3, !140, !DIExpression(DW_OP_deref), !141)
  %8 = call i32 inttoptr (i32 2 to ptr)(ptr noundef nonnull @start_ts, ptr noundef nonnull %2, ptr noundef nonnull %3, i64 noundef zeroext 0) #2, !dbg !157
  br label %9, !dbg !158

9:                                                ; preds = %1, %7
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %3) #2, !dbg !158
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %2) #2, !dbg !158
  ret i32 0, !dbg !158
}

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture) #1

; Function Attrs: nounwind
define dso_local noundef i32 @trace_wg_end(ptr nocapture noundef readonly %0) #0 section "kprobe/wg_socket_send_skb_to_peer" !dbg !159 {
  %2 = alloca i32, align 4
  %3 = alloca i64, align 8
    #dbg_value(ptr %0, !161, !DIExpression(), !173)
  %4 = getelementptr inbounds nuw i8, ptr %0, i32 52, !dbg !174
  %5 = load i32, ptr %4, align 4, !dbg !174, !tbaa !143
    #dbg_value(i32 %5, !162, !DIExpression(), !173)
  %6 = zext i32 %5 to i64, !dbg !175
    #dbg_value(i32 %5, !163, !DIExpression(DW_OP_LLVM_convert, 32, DW_ATE_unsigned, DW_OP_LLVM_convert, 64, DW_ATE_unsigned, DW_OP_stack_value), !173)
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %3) #2, !dbg !176
    #dbg_value(i64 0, !164, !DIExpression(), !173)
  store i64 0, ptr %3, align 8, !dbg !177, !tbaa !149
    #dbg_value(ptr %3, !164, !DIExpression(DW_OP_deref), !173)
  %7 = call ptr inttoptr (i32 1 to ptr)(ptr noundef nonnull @start_ts, ptr noundef nonnull %3) #2, !dbg !178
    #dbg_value(ptr %7, !165, !DIExpression(), !173)
  %.not = icmp eq ptr %7, null, !dbg !179
  br i1 %.not, label %24, label %8, !dbg !181

8:                                                ; preds = %1
  %9 = call i64 inttoptr (i32 5 to ptr)() #2, !dbg !182
  %10 = load i64, ptr %7, align 8, !dbg !183, !tbaa !149
  %11 = sub i64 %9, %10, !dbg !184
    #dbg_value(i64 %11, !166, !DIExpression(), !173)
    #dbg_value(ptr %3, !164, !DIExpression(DW_OP_deref), !173)
  %12 = call i32 inttoptr (i32 3 to ptr)(ptr noundef nonnull @start_ts, ptr noundef nonnull %3) #2, !dbg !185
  call void @llvm.lifetime.start.p0(i64 4, ptr nonnull %2) #2, !dbg !186
    #dbg_value(i32 0, !191, !DIExpression(), !196)
  store i32 0, ptr %2, align 4, !dbg !197, !tbaa !198
  %13 = call i64 inttoptr (i32 5 to ptr)() #2, !dbg !200
    #dbg_value(i64 %13, !192, !DIExpression(), !196)
    #dbg_value(ptr %2, !191, !DIExpression(DW_OP_deref), !196)
  %14 = call ptr inttoptr (i32 1 to ptr)(ptr noundef nonnull @last_emit_ts, ptr noundef nonnull %2) #2, !dbg !201
    #dbg_value(ptr %14, !193, !DIExpression(), !196)
  %.not.i = icmp eq ptr %14, null, !dbg !202
  br i1 %.not.i, label %should_emit.exit.thread, label %15, !dbg !204

15:                                               ; preds = %8
  %16 = load i64, ptr %14, align 8, !dbg !205, !tbaa !149
  %17 = icmp ne i64 %16, 0, !dbg !207
  %18 = sub i64 %13, %16
  %19 = icmp ult i64 %18, 50000000
  %or.cond = select i1 %17, i1 %19, i1 false, !dbg !207
  br i1 %or.cond, label %should_emit.exit.thread, label %20, !dbg !207

should_emit.exit.thread:                          ; preds = %15, %8
  call void @llvm.lifetime.end.p0(i64 4, ptr nonnull %2) #2, !dbg !208
  br label %24, !dbg !209

20:                                               ; preds = %15
  store i64 %13, ptr %14, align 8, !dbg !196, !tbaa !149
  call void @llvm.lifetime.end.p0(i64 4, ptr nonnull %2) #2, !dbg !208
  %21 = call ptr inttoptr (i32 131 to ptr)(ptr noundef nonnull @events, i64 noundef zeroext 16, i64 noundef zeroext 0) #2, !dbg !210
    #dbg_value(ptr %21, !167, !DIExpression(), !173)
  %.not13 = icmp eq ptr %21, null, !dbg !211
  br i1 %.not13, label %24, label %22, !dbg !213

22:                                               ; preds = %20
  store i64 %6, ptr %21, align 8, !dbg !214, !tbaa !215
  %23 = getelementptr inbounds nuw i8, ptr %21, i32 8, !dbg !217
  store i64 %11, ptr %23, align 8, !dbg !218, !tbaa !219
  call void inttoptr (i32 132 to ptr)(ptr noundef nonnull %21, i64 noundef zeroext 0) #2, !dbg !220
  br label %24, !dbg !221

24:                                               ; preds = %should_emit.exit.thread, %20, %22, %1
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %3) #2, !dbg !222
  ret i32 0, !dbg !222
}

attributes #0 = { nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mips32r2" "target-features"="+fpxx,+mips32r2,+nooddspreg,-noabicalls" }
attributes #1 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { nounwind }

!llvm.dbg.cu = !{!2}
!llvm.module.flags = !{!103, !104, !105, !106, !107}
!llvm.ident = !{!108}

!0 = !DIGlobalVariableExpression(var: !1, expr: !DIExpression())
!1 = distinct !DIGlobalVariable(name: "LICENSE", scope: !2, file: !16, line: 56, type: !99, isLocal: false, isDefinition: true)
!2 = distinct !DICompileUnit(language: DW_LANG_C11, file: !3, producer: "Ubuntu clang version 20.1.2 (0ubuntu1)", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, enums: !4, retainedTypes: !13, globals: !18, splitDebugInlining: false, nameTableKind: None)
!3 = !DIFile(filename: "/home/lemoer/git/ff/veth-batman/openwrt/net/wg-trace-delay-c/../../../bpf/wg_trace_delay.bpf.c", directory: "/home/lemoer/git/ff/veth-batman/openwrt/net/wg-trace-delay-c", checksumkind: CSK_MD5, checksum: "d3702be18bd2ad145eec57e20e67899e")
!4 = !{!5}
!5 = !DICompositeType(tag: DW_TAG_enumeration_type, file: !6, line: 1280, baseType: !7, size: 32, elements: !8)
!6 = !DIFile(filename: "gluon/openwrt/staging_dir/target-mips_24kc_musl/bpf-headers/include/uapi/linux/bpf.h", directory: "/home/lemoer/git/ff", checksumkind: CSK_MD5, checksum: "9eb2958afadfee30100ea879b24a3e93")
!7 = !DIBasicType(name: "unsigned int", size: 32, encoding: DW_ATE_unsigned)
!8 = !{!9, !10, !11, !12}
!9 = !DIEnumerator(name: "BPF_ANY", value: 0)
!10 = !DIEnumerator(name: "BPF_NOEXIST", value: 1)
!11 = !DIEnumerator(name: "BPF_EXIST", value: 2)
!12 = !DIEnumerator(name: "BPF_F_LOCK", value: 4)
!13 = !{!14, !15}
!14 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: null, size: 32)
!15 = !DIDerivedType(tag: DW_TAG_typedef, name: "__u64", file: !16, line: 15, baseType: !17)
!16 = !DIFile(filename: "../../../bpf/wg_trace_delay.bpf.c", directory: "/home/lemoer/git/ff/veth-batman/openwrt/net/wg-trace-delay-c", checksumkind: CSK_MD5, checksum: "d3702be18bd2ad145eec57e20e67899e")
!17 = !DIBasicType(name: "unsigned long long", size: 64, encoding: DW_ATE_unsigned)
!18 = !{!0, !19, !37, !51, !65, !71, !79, !84, !89, !94}
!19 = !DIGlobalVariableExpression(var: !20, expr: !DIExpression())
!20 = distinct !DIGlobalVariable(name: "start_ts", scope: !2, file: !16, line: 69, type: !21, isLocal: false, isDefinition: true)
!21 = distinct !DICompositeType(tag: DW_TAG_structure_type, file: !16, line: 64, size: 128, elements: !22)
!22 = !{!23, !29, !34, !36}
!23 = !DIDerivedType(tag: DW_TAG_member, name: "type", scope: !21, file: !16, line: 65, baseType: !24, size: 32)
!24 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !25, size: 32)
!25 = !DICompositeType(tag: DW_TAG_array_type, baseType: !26, size: 32, elements: !27)
!26 = !DIBasicType(name: "int", size: 32, encoding: DW_ATE_signed)
!27 = !{!28}
!28 = !DISubrange(count: 1)
!29 = !DIDerivedType(tag: DW_TAG_member, name: "max_entries", scope: !21, file: !16, line: 66, baseType: !30, size: 32, offset: 32)
!30 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !31, size: 32)
!31 = !DICompositeType(tag: DW_TAG_array_type, baseType: !26, size: 524288, elements: !32)
!32 = !{!33}
!33 = !DISubrange(count: 16384)
!34 = !DIDerivedType(tag: DW_TAG_member, name: "key", scope: !21, file: !16, line: 67, baseType: !35, size: 32, offset: 64)
!35 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !15, size: 32)
!36 = !DIDerivedType(tag: DW_TAG_member, name: "value", scope: !21, file: !16, line: 68, baseType: !35, size: 32, offset: 96)
!37 = !DIGlobalVariableExpression(var: !38, expr: !DIExpression())
!38 = distinct !DIGlobalVariable(name: "events", scope: !2, file: !16, line: 77, type: !39, isLocal: false, isDefinition: true)
!39 = distinct !DICompositeType(tag: DW_TAG_structure_type, file: !16, line: 74, size: 64, elements: !40)
!40 = !{!41, !46}
!41 = !DIDerivedType(tag: DW_TAG_member, name: "type", scope: !39, file: !16, line: 75, baseType: !42, size: 32)
!42 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !43, size: 32)
!43 = !DICompositeType(tag: DW_TAG_array_type, baseType: !26, size: 864, elements: !44)
!44 = !{!45}
!45 = !DISubrange(count: 27)
!46 = !DIDerivedType(tag: DW_TAG_member, name: "max_entries", scope: !39, file: !16, line: 76, baseType: !47, size: 32, offset: 32)
!47 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !48, size: 32)
!48 = !DICompositeType(tag: DW_TAG_array_type, baseType: !26, size: 33554432, elements: !49)
!49 = !{!50}
!50 = !DISubrange(count: 1048576)
!51 = !DIGlobalVariableExpression(var: !52, expr: !DIExpression())
!52 = distinct !DIGlobalVariable(name: "last_emit_ts", scope: !2, file: !16, line: 87, type: !53, isLocal: false, isDefinition: true)
!53 = distinct !DICompositeType(tag: DW_TAG_structure_type, file: !16, line: 82, size: 128, elements: !54)
!54 = !{!55, !60, !61, !64}
!55 = !DIDerivedType(tag: DW_TAG_member, name: "type", scope: !53, file: !16, line: 83, baseType: !56, size: 32)
!56 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !57, size: 32)
!57 = !DICompositeType(tag: DW_TAG_array_type, baseType: !26, size: 64, elements: !58)
!58 = !{!59}
!59 = !DISubrange(count: 2)
!60 = !DIDerivedType(tag: DW_TAG_member, name: "max_entries", scope: !53, file: !16, line: 84, baseType: !24, size: 32, offset: 32)
!61 = !DIDerivedType(tag: DW_TAG_member, name: "key", scope: !53, file: !16, line: 85, baseType: !62, size: 32, offset: 64)
!62 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !63, size: 32)
!63 = !DIDerivedType(tag: DW_TAG_typedef, name: "__u32", file: !16, line: 14, baseType: !7)
!64 = !DIDerivedType(tag: DW_TAG_member, name: "value", scope: !53, file: !16, line: 86, baseType: !35, size: 32, offset: 96)
!65 = !DIGlobalVariableExpression(var: !66, expr: !DIExpression(DW_OP_constu, 5, DW_OP_stack_value))
!66 = distinct !DIGlobalVariable(name: "bpf_ktime_get_ns", scope: !2, file: !67, line: 114, type: !68, isLocal: true, isDefinition: true)
!67 = !DIFile(filename: "gluon/openwrt/staging_dir/target-mips_24kc_musl/bpf-headers/tools/lib/bpf/bpf_helper_defs.h", directory: "/home/lemoer/git/ff", checksumkind: CSK_MD5, checksum: "d144f93c3f72a129a3efe01d7409cbe0")
!68 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !69, size: 32)
!69 = !DISubroutineType(types: !70)
!70 = !{!15}
!71 = !DIGlobalVariableExpression(var: !72, expr: !DIExpression(DW_OP_constu, 2, DW_OP_stack_value))
!72 = distinct !DIGlobalVariable(name: "bpf_map_update_elem", scope: !2, file: !67, line: 78, type: !73, isLocal: true, isDefinition: true)
!73 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !74, size: 32)
!74 = !DISubroutineType(types: !75)
!75 = !{!76, !14, !77, !77, !15}
!76 = !DIBasicType(name: "long", size: 32, encoding: DW_ATE_signed)
!77 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !78, size: 32)
!78 = !DIDerivedType(tag: DW_TAG_const_type, baseType: null)
!79 = !DIGlobalVariableExpression(var: !80, expr: !DIExpression(DW_OP_constu, 1, DW_OP_stack_value))
!80 = distinct !DIGlobalVariable(name: "bpf_map_lookup_elem", scope: !2, file: !67, line: 56, type: !81, isLocal: true, isDefinition: true)
!81 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !82, size: 32)
!82 = !DISubroutineType(types: !83)
!83 = !{!14, !14, !77}
!84 = !DIGlobalVariableExpression(var: !85, expr: !DIExpression(DW_OP_constu, 3, DW_OP_stack_value))
!85 = distinct !DIGlobalVariable(name: "bpf_map_delete_elem", scope: !2, file: !67, line: 88, type: !86, isLocal: true, isDefinition: true)
!86 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !87, size: 32)
!87 = !DISubroutineType(types: !88)
!88 = !{!76, !14, !77}
!89 = !DIGlobalVariableExpression(var: !90, expr: !DIExpression(DW_OP_constu, 131, DW_OP_stack_value))
!90 = distinct !DIGlobalVariable(name: "bpf_ringbuf_reserve", scope: !2, file: !67, line: 3177, type: !91, isLocal: true, isDefinition: true)
!91 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !92, size: 32)
!92 = !DISubroutineType(types: !93)
!93 = !{!14, !14, !15, !15}
!94 = !DIGlobalVariableExpression(var: !95, expr: !DIExpression(DW_OP_constu, 132, DW_OP_stack_value))
!95 = distinct !DIGlobalVariable(name: "bpf_ringbuf_submit", scope: !2, file: !67, line: 3195, type: !96, isLocal: true, isDefinition: true)
!96 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !97, size: 32)
!97 = !DISubroutineType(types: !98)
!98 = !{null, !14, !15}
!99 = !DICompositeType(tag: DW_TAG_array_type, baseType: !100, size: 32, elements: !101)
!100 = !DIBasicType(name: "char", size: 8, encoding: DW_ATE_signed_char)
!101 = !{!102}
!102 = !DISubrange(count: 4)
!103 = !{i32 7, !"Dwarf Version", i32 5}
!104 = !{i32 2, !"Debug Info Version", i32 3}
!105 = !{i32 1, !"wchar_size", i32 4}
!106 = !{i32 8, !"PIC Level", i32 1}
!107 = !{i32 7, !"PIE Level", i32 1}
!108 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1)"}
!109 = distinct !DISubprogram(name: "trace_wg_start", scope: !16, file: !16, line: 117, type: !110, scopeLine: 118, flags: DIFlagPrototyped | DIFlagAllCallsDescribed, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !2, retainedNodes: !135)
!110 = !DISubroutineType(types: !111)
!111 = !{!26, !112}
!112 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !113, size: 32)
!113 = distinct !DICompositeType(tag: DW_TAG_structure_type, name: "pt_regs", file: !114, line: 28, size: 1472, align: 64, elements: !115)
!114 = !DIFile(filename: "gluon/openwrt/staging_dir/target-mips_24kc_musl/bpf-headers/arch/mips/include/asm/ptrace.h", directory: "/home/lemoer/git/ff", checksumkind: CSK_MD5, checksum: "efe65e32c09f231267beab20bb8aec8a")
!115 = !{!116, !121, !125, !126, !127, !128, !129, !130, !131}
!116 = !DIDerivedType(tag: DW_TAG_member, name: "pad0", scope: !113, file: !114, line: 31, baseType: !117, size: 256)
!117 = !DICompositeType(tag: DW_TAG_array_type, baseType: !118, size: 256, elements: !119)
!118 = !DIBasicType(name: "unsigned long", size: 32, encoding: DW_ATE_unsigned)
!119 = !{!120}
!120 = !DISubrange(count: 8)
!121 = !DIDerivedType(tag: DW_TAG_member, name: "regs", scope: !113, file: !114, line: 35, baseType: !122, size: 1024, offset: 256)
!122 = !DICompositeType(tag: DW_TAG_array_type, baseType: !118, size: 1024, elements: !123)
!123 = !{!124}
!124 = !DISubrange(count: 32)
!125 = !DIDerivedType(tag: DW_TAG_member, name: "cp0_status", scope: !113, file: !114, line: 38, baseType: !118, size: 32, offset: 1280)
!126 = !DIDerivedType(tag: DW_TAG_member, name: "hi", scope: !113, file: !114, line: 39, baseType: !118, size: 32, offset: 1312)
!127 = !DIDerivedType(tag: DW_TAG_member, name: "lo", scope: !113, file: !114, line: 40, baseType: !118, size: 32, offset: 1344)
!128 = !DIDerivedType(tag: DW_TAG_member, name: "cp0_badvaddr", scope: !113, file: !114, line: 44, baseType: !118, size: 32, offset: 1376)
!129 = !DIDerivedType(tag: DW_TAG_member, name: "cp0_cause", scope: !113, file: !114, line: 45, baseType: !118, size: 32, offset: 1408)
!130 = !DIDerivedType(tag: DW_TAG_member, name: "cp0_epc", scope: !113, file: !114, line: 46, baseType: !118, size: 32, offset: 1440)
!131 = !DIDerivedType(tag: DW_TAG_member, name: "__last", scope: !113, file: !114, line: 51, baseType: !132, offset: 1472)
!132 = !DICompositeType(tag: DW_TAG_array_type, baseType: !118, elements: !133)
!133 = !{!134}
!134 = !DISubrange(count: 0)
!135 = !{!136, !137, !138, !139, !140}
!136 = !DILocalVariable(name: "ctx", arg: 1, scope: !109, file: !16, line: 117, type: !112)
!137 = !DILocalVariable(name: "skb", scope: !109, file: !16, line: 119, type: !14)
!138 = !DILocalVariable(name: "raw", scope: !109, file: !16, line: 120, type: !15)
!139 = !DILocalVariable(name: "key", scope: !109, file: !16, line: 121, type: !15)
!140 = !DILocalVariable(name: "ts", scope: !109, file: !16, line: 122, type: !15)
!141 = !DILocation(line: 0, scope: !109)
!142 = !DILocation(line: 119, column: 25, scope: !109)
!143 = !{!144, !144, i64 0}
!144 = !{!"long", !145, i64 0}
!145 = !{!"omnipotent char", !146, i64 0}
!146 = !{!"Simple C/C++ TBAA"}
!147 = !DILocation(line: 121, column: 5, scope: !109)
!148 = !DILocation(line: 121, column: 11, scope: !109)
!149 = !{!150, !150, i64 0}
!150 = !{!"long long", !145, i64 0}
!151 = !DILocation(line: 122, column: 5, scope: !109)
!152 = !DILocation(line: 122, column: 16, scope: !109)
!153 = !DILocation(line: 122, column: 11, scope: !109)
!154 = !DILocation(line: 124, column: 10, scope: !155)
!155 = distinct !DILexicalBlock(scope: !109, file: !16, line: 124, column: 9)
!156 = !DILocation(line: 124, column: 9, scope: !155)
!157 = !DILocation(line: 127, column: 5, scope: !109)
!158 = !DILocation(line: 144, column: 1, scope: !109)
!159 = distinct !DISubprogram(name: "trace_wg_end", scope: !16, file: !16, line: 152, type: !110, scopeLine: 153, flags: DIFlagPrototyped | DIFlagAllCallsDescribed, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !2, retainedNodes: !160)
!160 = !{!161, !162, !163, !164, !165, !166, !167}
!161 = !DILocalVariable(name: "ctx", arg: 1, scope: !159, file: !16, line: 152, type: !112)
!162 = !DILocalVariable(name: "skb", scope: !159, file: !16, line: 159, type: !14)
!163 = !DILocalVariable(name: "raw", scope: !159, file: !16, line: 160, type: !15)
!164 = !DILocalVariable(name: "key", scope: !159, file: !16, line: 161, type: !15)
!165 = !DILocalVariable(name: "start_ts_ptr", scope: !159, file: !16, line: 174, type: !35)
!166 = !DILocalVariable(name: "delta_ns", scope: !159, file: !16, line: 178, type: !15)
!167 = !DILocalVariable(name: "e2", scope: !159, file: !16, line: 184, type: !168)
!168 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !169, size: 32)
!169 = distinct !DICompositeType(tag: DW_TAG_structure_type, name: "event_t", file: !16, line: 58, size: 128, elements: !170)
!170 = !{!171, !172}
!171 = !DIDerivedType(tag: DW_TAG_member, name: "id", scope: !169, file: !16, line: 59, baseType: !15, size: 64)
!172 = !DIDerivedType(tag: DW_TAG_member, name: "delta_ns", scope: !169, file: !16, line: 60, baseType: !15, size: 64, offset: 64)
!173 = !DILocation(line: 0, scope: !159)
!174 = !DILocation(line: 159, column: 25, scope: !159)
!175 = !DILocation(line: 160, column: 17, scope: !159)
!176 = !DILocation(line: 161, column: 5, scope: !159)
!177 = !DILocation(line: 161, column: 11, scope: !159)
!178 = !DILocation(line: 174, column: 27, scope: !159)
!179 = !DILocation(line: 175, column: 10, scope: !180)
!180 = distinct !DILexicalBlock(scope: !159, file: !16, line: 175, column: 9)
!181 = !DILocation(line: 175, column: 9, scope: !180)
!182 = !DILocation(line: 178, column: 22, scope: !159)
!183 = !DILocation(line: 178, column: 43, scope: !159)
!184 = !DILocation(line: 178, column: 41, scope: !159)
!185 = !DILocation(line: 179, column: 5, scope: !159)
!186 = !DILocation(line: 91, column: 5, scope: !187, inlinedAt: !194)
!187 = distinct !DISubprogram(name: "should_emit", scope: !16, file: !16, line: 89, type: !188, scopeLine: 90, flags: DIFlagPrototyped | DIFlagAllCallsDescribed, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !2, retainedNodes: !190)
!188 = !DISubroutineType(types: !189)
!189 = !{!26}
!190 = !{!191, !192, !193}
!191 = !DILocalVariable(name: "idx", scope: !187, file: !16, line: 91, type: !63)
!192 = !DILocalVariable(name: "now", scope: !187, file: !16, line: 92, type: !15)
!193 = !DILocalVariable(name: "last", scope: !187, file: !16, line: 93, type: !35)
!194 = distinct !DILocation(line: 181, column: 10, scope: !195)
!195 = distinct !DILexicalBlock(scope: !159, file: !16, line: 181, column: 9)
!196 = !DILocation(line: 0, scope: !187, inlinedAt: !194)
!197 = !DILocation(line: 91, column: 11, scope: !187, inlinedAt: !194)
!198 = !{!199, !199, i64 0}
!199 = !{!"int", !145, i64 0}
!200 = !DILocation(line: 92, column: 17, scope: !187, inlinedAt: !194)
!201 = !DILocation(line: 93, column: 19, scope: !187, inlinedAt: !194)
!202 = !DILocation(line: 95, column: 10, scope: !203, inlinedAt: !194)
!203 = distinct !DILexicalBlock(scope: !187, file: !16, line: 95, column: 9)
!204 = !DILocation(line: 95, column: 9, scope: !203, inlinedAt: !194)
!205 = !DILocation(line: 98, column: 9, scope: !206, inlinedAt: !194)
!206 = distinct !DILexicalBlock(scope: !187, file: !16, line: 98, column: 9)
!207 = !DILocation(line: 98, column: 15, scope: !206, inlinedAt: !194)
!208 = !DILocation(line: 108, column: 1, scope: !187, inlinedAt: !194)
!209 = !DILocation(line: 181, column: 9, scope: !195)
!210 = !DILocation(line: 184, column: 26, scope: !159)
!211 = !DILocation(line: 185, column: 10, scope: !212)
!212 = distinct !DILexicalBlock(scope: !159, file: !16, line: 185, column: 9)
!213 = !DILocation(line: 185, column: 9, scope: !212)
!214 = !DILocation(line: 188, column: 12, scope: !159)
!215 = !{!216, !150, i64 0}
!216 = !{!"event_t", !150, i64 0, !150, i64 8}
!217 = !DILocation(line: 189, column: 9, scope: !159)
!218 = !DILocation(line: 189, column: 18, scope: !159)
!219 = !{!216, !150, i64 8}
!220 = !DILocation(line: 191, column: 5, scope: !159)
!221 = !DILocation(line: 193, column: 5, scope: !159)
!222 = !DILocation(line: 194, column: 1, scope: !159)
