import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/question_provider.dart';
import '../../models/question_model.dart';
import '../../services/image_service.dart';
import '../shared/katex_widget.dart';

class CreateQuestionTab extends StatefulWidget {
  const CreateQuestionTab({super.key});

  @override
  State<CreateQuestionTab> createState() => _CreateQuestionTabState();
}

class _CreateQuestionTabState extends State<CreateQuestionTab> {
  final _questionCtrl = TextEditingController();
  final _opt1Ctrl = TextEditingController();
  final _opt2Ctrl = TextEditingController();
  final _opt3Ctrl = TextEditingController();
  final _opt4Ctrl = TextEditingController();
  final _correctCtrl = TextEditingController();
  final _chapterCtrl = TextEditingController();

  int _selectedClass = 10;
  String _selectedLanguage = 'English';

  final _imageService = ImageService();

  @override
  void initState() {
    super.initState();
    // When first question in queue changes, populate form
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromQueue();
    });
  }

  void _syncFromQueue() {
    final provider = Provider.of<QuestionProvider>(context, listen: false);
    if (provider.questionQueue.isNotEmpty) {
      final scan = provider.questionQueue.first;
      _questionCtrl.text = scan.questionText;
      if (scan.options.length >= 4) {
        _opt1Ctrl.text = scan.options[0];
        _opt2Ctrl.text = scan.options[1];
        _opt3Ctrl.text = scan.options[2];
        _opt4Ctrl.text = scan.options[3];
      }
      if (scan.correctAnswer != null) _correctCtrl.text = scan.correctAnswer!;
      setState(() {});
    }
  }

  void _clearForm() {
    _questionCtrl.clear();
    _opt1Ctrl.clear();
    _opt2Ctrl.clear();
    _opt3Ctrl.clear();
    _opt4Ctrl.clear();
    _correctCtrl.clear();
    _chapterCtrl.clear();
  }

  Future<void> _scanImage() async {
    final file = await _imageService.pickAndCropImage(context);
    if (file == null || !mounted) return;

    final provider = Provider.of<QuestionProvider>(context, listen: false);
    await provider.scanImage(file);

    if (!mounted) return;
    if (provider.creationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.creationError!), backgroundColor: Colors.red.shade700),
      );
    } else if (provider.questionQueue.isNotEmpty) {
      _syncFromQueue();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${provider.questionQueue.length} question(s) extracted!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  Future<void> _saveQuestion() async {
    if (_questionCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question text is required'), backgroundColor: Colors.red),
      );
      return;
    }

    final provider = Provider.of<QuestionProvider>(context, listen: false);
    final q = Question(
      questionText: _questionCtrl.text.trim(),
      options: [_opt1Ctrl.text.trim(), _opt2Ctrl.text.trim(), _opt3Ctrl.text.trim(), _opt4Ctrl.text.trim()],
      correctAnswer: _correctCtrl.text.trim(),
      classNo: _selectedClass,
      language: _selectedLanguage,
      chapter: _chapterCtrl.text.trim(),
    );

    final success = await provider.saveQuestion(q);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.questionQueue.length > 1 ? 'Saved! Loading next...' : 'Question saved!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      _clearForm();
      if (provider.questionQueue.isNotEmpty) {
        provider.popQuestionFromQueue();
        _syncFromQueue();
      }
      provider.resetCreationStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.creationError ?? 'Failed to save'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _opt1Ctrl.dispose();
    _opt2Ctrl.dispose();
    _opt3Ctrl.dispose();
    _opt4Ctrl.dispose();
    _correctCtrl.dispose();
    _chapterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuestionProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Queue indicator
              if (provider.questionQueue.length > 1)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE7F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.queue, color: Color(0xFF673AB7)),
                      const SizedBox(width: 12),
                      Text(
                        'Queue: ${provider.questionQueue.length} questions remaining',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF673AB7)),
                      ),
                    ],
                  ),
                ),

              // Scan Buttons
              Row(
                children: [
                  Expanded(
                    child: _scanButton(
                      label: 'Camera Scan',
                      icon: Icons.photo_camera,
                      onPressed: provider.isScanning ? null : _scanImage,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _scanButton(
                      label: 'Gallery',
                      icon: Icons.collections,
                      onPressed: provider.isScanning ? null : _scanImage,
                    ),
                  ),
                ],
              ),
              if (provider.isScanning) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(color: Color(0xFF673AB7), backgroundColor: Color(0xFFEDE7F6)),
                const SizedBox(height: 4),
                const Text('Analyzing image with AI...', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
              const SizedBox(height: 20),

              // Question Text
              _label('Question Text (KaTeX supported)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _questionCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: _inputDec('Enter question...'),
              ),

              // Preview if has LaTeX
              if (_questionCtrl.text.contains(r'$') || _questionCtrl.text.contains(r'\(')) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: KaTeXWidget(text: _questionCtrl.text),
                ),
              ],

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('Chapter'),
                      const SizedBox(height: 8),
                      TextFormField(controller: _chapterCtrl, decoration: _inputDec('Chapter')),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('Class'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _selectedClass,
                        onChanged: (val) => setState(() => _selectedClass = val!),
                        decoration: _inputDec('Class'),
                        items: [9, 10, 11, 12].map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                      ),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Language
              _label('Language'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                onChanged: (val) => setState(() => _selectedLanguage = val!),
                decoration: _inputDec('Language'),
                items: ['Bengali', 'English', 'Both'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
              ),
              const SizedBox(height: 20),

              _label('Options'),
              const SizedBox(height: 8),
              TextFormField(controller: _opt1Ctrl, decoration: _inputDec('Option 1')),
              const SizedBox(height: 10),
              TextFormField(controller: _opt2Ctrl, decoration: _inputDec('Option 2')),
              const SizedBox(height: 10),
              TextFormField(controller: _opt3Ctrl, decoration: _inputDec('Option 3')),
              const SizedBox(height: 10),
              TextFormField(controller: _opt4Ctrl, decoration: _inputDec('Option 4')),
              const SizedBox(height: 16),

              _label('Correct Answer'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _correctCtrl,
                decoration: _inputDec('Paste exact correct option text'),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: provider.isSaving
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF673AB7)))
                    : ElevatedButton(
                        onPressed: _saveQuestion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF673AB7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                        child: Text(
                          provider.questionQueue.length > 1 ? 'Save & Load Next' : 'Save Question',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
                        ),
                      ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _label(String text) {
    return Text(text, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 13));
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF673AB7), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _scanButton({required String label, required IconData icon, required VoidCallback? onPressed}) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF673AB7),
        side: const BorderSide(color: Color(0xFF673AB7)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
