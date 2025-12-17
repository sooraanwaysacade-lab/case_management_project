import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'cases_screen.dart';
import 'appeal_screen.dart';

class CaseManagementScreen extends StatefulWidget {
  const CaseManagementScreen({super.key});

  @override
  State<CaseManagementScreen> createState() => _CaseManagementScreenState();
}

class _CaseManagementScreenState extends State<CaseManagementScreen> {
  // Helper to get ordinal number (1st, 2nd, 3rd, 4th, etc.)
  String _getOrdinal(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  // Helper to get semester start date (4-month semesters)
  // Current semester: Sep-Dec, Last semester: May-Aug, Second last: Jan-Apr
  DateTime _getSemesterStart(int semestersAgo) {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    
    // Determine current semester based on month
    // Sep-Dec (9-12): Current semester (0 semesters ago)
    // May-Aug (5-8): Last semester (1 semester ago)
    // Jan-Apr (1-4): Second last semester (2 semesters ago)
    
    int semesterOffset;
    int baseYear;
    int baseStartMonth;
    
    if (currentMonth >= 9 && currentMonth <= 12) {
      // Current semester: Sep-Dec
      semesterOffset = 0;
      baseYear = currentYear;
      baseStartMonth = 9;
    } else if (currentMonth >= 5 && currentMonth <= 8) {
      // Last semester: May-Aug
      semesterOffset = 1;
      baseYear = currentYear;
      baseStartMonth = 5;
    } else {
      // Second last semester: Jan-Apr
      semesterOffset = 2;
      baseYear = currentYear;
      baseStartMonth = 1;
    }
    
    // Calculate target semester
    int totalSemestersAgo = semesterOffset + semestersAgo;
    
    // Each semester is 4 months, so we need to go back totalSemestersAgo * 4 months
    int monthsToSubtract = totalSemestersAgo * 4;
    
    int targetYear = baseYear;
    int targetMonth = baseStartMonth;
    
    // Calculate target month and year
    targetMonth -= monthsToSubtract;
    while (targetMonth <= 0) {
      targetMonth += 12;
      targetYear--;
    }
    
    return DateTime(targetYear, targetMonth, 1);
  }

  // Helper to get semester end date (4 months after start)
  DateTime _getSemesterEnd(DateTime startDate) {
    int endMonth = startDate.month + 3; // 4 months total (start month + 3 more)
    int endYear = startDate.year;
    
    if (endMonth > 12) {
      endMonth -= 12;
      endYear++;
    }
    
    // Get the last day of the end month
    return DateTime(endYear, endMonth + 1, 0); // Day 0 of next month = last day of current month
  }

  // Get semester label with ordinal
  String _getSemesterLabel(int semestersAgo) {
    if (semestersAgo == 0) return 'Current Semester';
    if (semestersAgo == 1) return 'Last Semester';
    return '${_getOrdinal(semestersAgo)} Last Semester';
  }

  // Get date for last year
  DateTime _getLastYearDate() {
    return DateTime.now().subtract(const Duration(days: 365));
  }

  // Calculate statistics for a date range
  Map<String, dynamic> _calculateStats(
    List<DocumentSnapshot> allCases,
    DateTime startDate,
    String periodLabel,
  ) {
    final endDate = _getSemesterEnd(startDate);
    final filteredCases = allCases.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      final createdAt = data?['createdAt'] as Timestamp?;
      if (createdAt == null) return false;
      final caseDate = createdAt.toDate();
      // Include cases created on or after startDate and on or before endDate
      return !caseDate.isBefore(startDate) && !caseDate.isAfter(endDate);
    }).toList();

    final stats = {
      'total': filteredCases.length,
      'pending': 0,
      'resolved': 0,
      'suspension': 0,
      'expulsion': 0,
      'underInvestigation': 0,
      'periodLabel': periodLabel,
      'startDate': startDate,
    };

    for (var doc in filteredCases) {
      final data = doc.data() as Map<String, dynamic>?;
      final status = (data?['status'] ?? 'Pending').toString().toLowerCase();
      
      switch (status) {
        case 'pending':
          stats['pending'] = (stats['pending'] as int) + 1;
          break;
        case 'resolved':
          stats['resolved'] = (stats['resolved'] as int) + 1;
          break;
        case 'suspension':
          stats['suspension'] = (stats['suspension'] as int) + 1;
          break;
        case 'expulsion':
          stats['expulsion'] = (stats['expulsion'] as int) + 1;
          break;
        case 'under investigation':
          stats['underInvestigation'] = (stats['underInvestigation'] as int) + 1;
          break;
      }
    }

    return stats;
  }

  // Calculate appeals statistics
  Map<String, dynamic> _calculateAppealsStats(
    List<DocumentSnapshot> allAppeals,
    DateTime startDate,
  ) {
    final endDate = _getSemesterEnd(startDate);
    final filteredAppeals = allAppeals.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      final createdAt = data?['createdAt'] as Timestamp?;
      if (createdAt == null) return false;
      final appealDate = createdAt.toDate();
      // Include appeals created on or after startDate and on or before endDate
      return !appealDate.isBefore(startDate) && !appealDate.isAfter(endDate);
    }).toList();

    return {
      'total': filteredAppeals.length,
      'startDate': startDate,
    };
  }

  void _navigateToFilteredCases(String status, DateTime startDate, String semesterLabel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CasesScreen(
          semesterStartDate: startDate,
          initialStatusFilter: status,
          semesterLabel: semesterLabel,
        ),
      ),
    );
  }

  void _navigateToAppeals() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AppealScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark 
          ? Theme.of(context).scaffoldBackgroundColor 
          : const Color(0xFFF5F7FA),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('cases')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, casesSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('appeals')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, appealsSnapshot) {
              if (casesSnapshot.connectionState == ConnectionState.waiting ||
                  appealsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.indigo));
              }

              if (casesSnapshot.hasError || appealsSnapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading analytics',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final allCases = casesSnapshot.data?.docs ?? [];
              final allAppeals = appealsSnapshot.data?.docs ?? [];

              if (allCases.isEmpty && allAppeals.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 80,
                        color: isDark ? Colors.grey[600] : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No data available',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Analytics will appear here once cases are reported',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Calculate statistics for different periods
              final currentSemester = _calculateStats(
                allCases,
                _getSemesterStart(0),
                _getSemesterLabel(0),
              );
              final lastSemester = _calculateStats(
                allCases,
                _getSemesterStart(1),
                _getSemesterLabel(1),
              );
              final secondLastSemester = _calculateStats(
                allCases,
                _getSemesterStart(2),
                _getSemesterLabel(2),
              );
              final thirdLastSemester = _calculateStats(
                allCases,
                _getSemesterStart(3),
                _getSemesterLabel(3),
              );
              final fourthLastSemester = _calculateStats(
                allCases,
                _getSemesterStart(4),
                _getSemesterLabel(4),
              );
              final lastYear = _calculateStats(
                allCases,
                _getLastYearDate(),
                'Last Year',
              );

              // Appeals statistics
              final currentSemesterAppeals = _calculateAppealsStats(
                allAppeals,
                _getSemesterStart(0),
              );
              final lastSemesterAppeals = _calculateAppealsStats(
                allAppeals,
                _getSemesterStart(1),
              );
              final secondLastSemesterAppeals = _calculateAppealsStats(
                allAppeals,
                _getSemesterStart(2),
              );
              final thirdLastSemesterAppeals = _calculateAppealsStats(
                allAppeals,
                _getSemesterStart(3),
              );
              final fourthLastSemesterAppeals = _calculateAppealsStats(
                allAppeals,
                _getSemesterStart(4),
              );
              final lastYearAppeals = _calculateAppealsStats(
                allAppeals,
                _getLastYearDate(),
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Semester Statistics Section
                    Center(
                      child: Text(
                        'Semester Statistics',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.indigo.shade900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    _buildPeriodCard(context, currentSemester, currentSemesterAppeals['total'] as int),
                    const SizedBox(height: 16),
                    _buildPeriodCard(context, lastSemester, lastSemesterAppeals['total'] as int),
                    const SizedBox(height: 16),
                    _buildPeriodCard(context, secondLastSemester, secondLastSemesterAppeals['total'] as int),
                    const SizedBox(height: 16),
                    _buildPeriodCard(context, thirdLastSemester, thirdLastSemesterAppeals['total'] as int),
                    const SizedBox(height: 16),
                    _buildPeriodCard(context, fourthLastSemester, fourthLastSemesterAppeals['total'] as int),
                    const SizedBox(height: 24),

                    // Last Year Section
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Annual Statistics',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.indigo.shade900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildPeriodCard(context, lastYear, lastYearAppeals['total'] as int),
                    const SizedBox(height: 30),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPeriodCard(BuildContext context, Map<String, dynamic> stats, int appeals) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = stats['total'] as int;
    final startDate = stats['startDate'] as DateTime;
    final periodLabel = stats['periodLabel'] as String;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.4) 
                : Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Header Section with Gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.indigo.shade50,
                    Colors.indigo.shade100.withOpacity(0.5),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade600,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          periodLabel,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.indigo.shade900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM yyyy').format(startDate),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.indigo.shade600, Colors.indigo.shade700],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Status Chips Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Case Status Breakdown',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Status chips in pairs
                  Column(
                    children: [
                      // Row 1: Pending and Resolved
                      Row(
                        children: [
                          Expanded(
                            child: _buildClickableStatusChip(
                              context,
                              'Pending',
                              stats['pending'] as int,
                              Colors.orange,
                              startDate,
                              periodLabel,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildClickableStatusChip(
                              context,
                              'Resolved',
                              stats['resolved'] as int,
                              Colors.green,
                              startDate,
                              periodLabel,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Row 2: Suspension and Expulsion
                      Row(
                        children: [
                          Expanded(
                            child: _buildClickableStatusChip(
                              context,
                              'Suspension',
                              stats['suspension'] as int,
                              Colors.purple,
                              startDate,
                              periodLabel,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildClickableStatusChip(
                              context,
                              'Expulsion',
                              stats['expulsion'] as int,
                              Colors.red,
                              startDate,
                              periodLabel,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Row 3: Under Investigation and Appeals
                      Row(
                        children: [
                          Expanded(
                            child: _buildClickableStatusChip(
                              context,
                              'Under Investigation',
                              stats['underInvestigation'] as int,
                              Colors.blue,
                              startDate,
                              periodLabel,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildClickableAppealsChip(
                              context,
                              appeals,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClickableAppealsChip(
    BuildContext context,
    int count,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Colors.teal;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: count > 0 ? _navigateToAppeals : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: count > 0
                ? LinearGradient(
                    colors: [
                      color.withOpacity(0.15),
                      color.withOpacity(0.1),
                    ],
                  )
                : null,
            color: count == 0
                ? (isDark ? Colors.grey[800] : Colors.grey.shade100)
                : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: count > 0
                  ? color.withOpacity(0.4)
                  : (isDark ? Colors.grey[700]! : Colors.grey.shade300),
              width: 1.5,
            ),
            boxShadow: count > 0
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: count > 0
                      ? color.withOpacity(0.2)
                      : (isDark ? Colors.grey[700] : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.gavel_rounded,
                  size: 16,
                  color: count > 0 ? color : (isDark ? Colors.grey[500] : Colors.grey.shade500),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Appeals',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: count > 0
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.grey[500] : Colors.grey.shade500),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: count > 0
                      ? color
                      : (isDark ? Colors.grey[700] : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: count > 0 ? Colors.white : (isDark ? Colors.grey[500] : Colors.grey.shade500),
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: color,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClickableStatusChip(
    BuildContext context,
    String label,
    int count,
    Color color,
    DateTime startDate,
    String semesterLabel,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: count > 0
            ? () => _navigateToFilteredCases(label, startDate, semesterLabel)
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: count > 0
                ? LinearGradient(
                    colors: [
                      color.withOpacity(0.15),
                      color.withOpacity(0.1),
                    ],
                  )
                : null,
            color: count == 0
                ? (isDark ? Colors.grey[800] : Colors.grey.shade100)
                : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: count > 0
                  ? color.withOpacity(0.4)
                  : (isDark ? Colors.grey[700]! : Colors.grey.shade300),
              width: 1.5,
            ),
            boxShadow: count > 0
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: count > 0 ? color : (isDark ? Colors.grey[600] : Colors.grey.shade400),
                  shape: BoxShape.circle,
                  boxShadow: count > 0
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: count > 0
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.grey[500] : Colors.grey.shade500),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: count > 0
                      ? color
                      : (isDark ? Colors.grey[700] : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: count > 0 ? Colors.white : (isDark ? Colors.grey[500] : Colors.grey.shade500),
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: color,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
