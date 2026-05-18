import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';

class CreateTestScreen extends StatefulWidget {
  const CreateTestScreen({super.key});

  @override
  State<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends State<CreateTestScreen> {
  String _selectedDate = '';
  String _selectedTime = '';
  String _selectedClass = '10';
  String _selectedMedium = 'English';
  String _selectedQuestions = '20';
  String _totalTime = '30';

  final _classes = ['9', '10', '11', '12'];
  final _mediums = ['Bengali', 'English', 'Both'];
  final _questionOptions = ['20', '40', '50', '80', '100'];

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF673AB7)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF673AB7)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final h = picked.hourOfPeriod.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      setState(() => _selectedTime = '$h:$m $period');
    }
  }

  Future<void> _publishTest() async {
    if (_selectedDate.isEmpty) {
      _showSnack('Please select a date');
      return;
    }
    if (_selectedTime.isEmpty) {
      _showSnack('Please select a time');
      return;
    }

    final provider = Provider.of<AdminProvider>(context, listen: false);
    final success = await provider.createTest(
      date: _selectedDate,
      time: _selectedTime,
      classNo: int.parse(_selectedClass),
      language: _selectedMedium,
      totalQuestions: int.parse(_selectedQuestions),
      totalTime: int.tryParse(_totalTime) ?? 30,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Test published successfully!'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      _showSnack(provider.createTestError ?? 'Failed to create test');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF673AB7),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Test', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Test Configuration', const Color(0xFF673AB7)),
            const SizedBox(height: 16),

            // Date & Time Row
            Row(
              children: [
                Expanded(
                  child: _dateTimeCard(
                    label: 'Date',
                    value: _selectedDate.isEmpty ? 'Select Date' : _selectedDate,
                    icon: Icons.calendar_today,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dateTimeCard(
                    label: 'Time',
                    value: _selectedTime.isEmpty ? 'Select Time' : _selectedTime,
                    icon: Icons.schedule,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Class Selector
            _buildDropdown('Target Class', _selectedClass, _classes.map((c) => 'Class $c').toList(),
              _classes, (val) => setState(() => _selectedClass = val!), Icons.class_),
            const SizedBox(height: 16),

            // Medium Selector
            _buildDropdown('Language / Medium', _selectedMedium, _mediums, _mediums,
              (val) => setState(() => _selectedMedium = val!), Icons.translate),
            const SizedBox(height: 16),

            // Total Questions
            _buildDropdown('Total Questions', _selectedQuestions, _questionOptions, _questionOptions,
              (val) => setState(() => _selectedQuestions = val!), Icons.help_outline),
            const SizedBox(height: 16),

            // Total Time
            TextFormField(
              initialValue: _totalTime,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Duration (Minutes)',
                prefixIcon: const Icon(Icons.timer_outlined, color: Color(0xFF673AB7)),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF673AB7), width: 1.5),
                ),
              ),
              onChanged: (val) => _totalTime = val,
            ),
            const SizedBox(height: 32),

            Consumer<AdminProvider>(
              builder: (context, provider, _) => SizedBox(
                width: double.infinity,
                height: 56,
                child: provider.isCreatingTest
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF673AB7)))
                    : ElevatedButton(
                        onPressed: _publishTest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF673AB7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                        child: const Text(
                          'Publish Test',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color),
    );
  }

  Widget _dateTimeCard({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE7F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF673AB7).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF673AB7), size: 18),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Color(0xFF673AB7), fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> displayOptions, List<String> values,
      ValueChanged<String?> onChanged, IconData icon) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF673AB7)),
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF673AB7), width: 1.5),
        ),
      ),
      items: List.generate(values.length, (i) => DropdownMenuItem(
        value: values[i],
        child: Text(displayOptions[i]),
      )),
    );
  }
}
