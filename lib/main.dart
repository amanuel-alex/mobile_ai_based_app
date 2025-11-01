import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_ai_photo_editor/core/services/di_container.dart';
import 'package:mobile_ai_photo_editor/features/presentation/bloc/editor_cubit.dart';
import 'package:mobile_ai_photo_editor/features/screens/editor_screen.dart';
import 'package:mobile_ai_photo_editor/shared/styles/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  runApp(const EditorApp());
}

class EditorApp extends StatelessWidget {
  const EditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<EditorCubit>(create: (_) => sl<EditorCubit>()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mobile AI Photo Editor',
        theme: buildAppTheme(),
        home: const EditorScreen(),
      ),
    );
  }
}

