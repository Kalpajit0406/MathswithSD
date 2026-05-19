import 'package:flutter/material.dart';

/// Widget to display question difficulty level as a visual badge
class DifficultyBadge extends StatelessWidget {
  final double difficulty; // 1-5 scale
  final double successRate; // 0-100 percentage
  final bool compact; // Compact or expanded display

  const DifficultyBadge({
    Key? key,
    required this.difficulty,
    this.successRate = 0,
    this.compact = false,
  }) : super(key: key);

  Color _getDifficultyColor() {
    if (difficulty <= 1.5) return Colors.green;
    if (difficulty <= 2.5) return Colors.blue;
    if (difficulty <= 3.5) return Colors.amber;
    if (difficulty <= 4.5) return Colors.orange;
    return Colors.red;
  }

  String _getDifficultyLabel() {
    if (difficulty <= 1.5) return 'Easy';
    if (difficulty <= 2.5) return 'Medium';
    if (difficulty <= 3.5) return 'Hard';
    if (difficulty <= 4.5) return 'Very Hard';
    return 'Expert';
  }

  int _getStarCount() {
    return ((difficulty + 0.4) / 1.0).floor().clamp(1, 5);
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getDifficultyColor().withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getDifficultyColor(),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(
              _getStarCount(),
              (index) => Icon(
                Icons.star,
                size: 14,
                color: _getDifficultyColor(),
              ),
            ),
            SizedBox(width: 4),
            Text(
              _getDifficultyLabel(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getDifficultyColor(),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getDifficultyColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getDifficultyColor().withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                color: _getDifficultyColor(),
                size: 20,
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Difficulty Level',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _getDifficultyLabel(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _getDifficultyColor(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
              (index) => Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.star,
                  size: 18,
                  color: index < _getStarCount()
                      ? _getDifficultyColor()
                      : Colors.grey[300],
                ),
              ),
            ),
          ),
          if (successRate > 0) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Success Rate: ${successRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Difficulty indicator for question preview in lists
class DifficultyIndicator extends StatelessWidget {
  final double difficulty;
  final EdgeInsets padding;

  const DifficultyIndicator({
    Key? key,
    required this.difficulty,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  }) : super(key: key);

  Color _getColor() {
    if (difficulty <= 1.5) return Colors.green;
    if (difficulty <= 2.5) return Colors.blue;
    if (difficulty <= 3.5) return Colors.amber;
    if (difficulty <= 4.5) return Colors.orange;
    return Colors.red;
  }

  String _getLabel() {
    if (difficulty <= 1.5) return 'E';
    if (difficulty <= 2.5) return 'M';
    if (difficulty <= 3.5) return 'H';
    if (difficulty <= 4.5) return 'VH';
    return 'X';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _getColor().withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Text(
        _getLabel(),
        style: TextStyle(
          color: _getColor(),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
