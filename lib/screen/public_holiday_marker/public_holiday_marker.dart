
import 'package:attendance_app/modals/attendance_holiday.dart';
import 'package:attendance_app/service/attendance_holiday/attendance_holiday_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PublicHolidayMarker extends StatefulWidget {
  const PublicHolidayMarker({super.key});

  @override
  State<PublicHolidayMarker> createState() =>
      _PublicHolidayMarkerState();
}

class _PublicHolidayMarkerState extends State<PublicHolidayMarker> {
  // =========================================================
  // COLORS
  // =========================================================

  static const Color backgroundColor = Color(0xFF273F4F);
  static const Color cardColor = Color(0xFF314B5C);
  static const Color textPrimary = Color(0xFFF1F2F6);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color accentColor = Colors.cyanAccent;
  static const Color successColor = Color(0xFF38EF7D);
  static const Color dangerColor = Color(0xFFFF6B6B);

  // =========================================================
  // SERVICE
  // =========================================================

  late final AttendanceHolidayService _holidayService;

  // =========================================================
  // STATE
  // =========================================================

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isDeleting = false;

  List<AttendanceHoliday> _holidays = [];

  DateTime _selectedMonth = DateTime.now();

  // =========================================================
  // LIFECYCLE
  // =========================================================

  @override
  void initState() {
    super.initState();

    final baseUrl =
        dotenv.env['API_BASE_URL']?.trim() ?? '';

    _holidayService = AttendanceHolidayService(
      baseUrl: baseUrl,
    );

    _loadHolidays();
  }

  // =========================================================
  // LOAD HOLIDAYS
  // =========================================================

  Future<void> _loadHolidays() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final holidays =
          await _holidayService.getByMonth(
        year: _selectedMonth.year,
        month: _selectedMonth.month,
      );

      if (!mounted) return;

      setState(() {
        _holidays = holidays;
      });
    } on AttendanceHolidayApiException catch (e) {
      if (!mounted) return;

      _showError(e.message);
    } catch (e) {
      if (!mounted) return;

      _showError(
        'Unable to connect to the server.\n\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // CREATE HOLIDAY
  // =========================================================
  Future<bool> _createHoliday({
    required DateTime date,
    required HolidayType holidayType,
    required String holidayName,
    required String description,
  }) async {
    if (!mounted) return false;

    setState(() {
      _isSaving = true;
    });

    try {
      final request = AttendanceHolidayRequest(
        holidayDate: date,
        holidayType: holidayType,
        holidayName: holidayName.trim(),
        description: description.trim().isEmpty
            ? null
            : description.trim(),
      );

      debugPrint('========================================');
      debugPrint('CREATE HOLIDAY');
      debugPrint('Date: ${request.holidayDate}');
      debugPrint('Type: ${request.holidayType.value}');
      debugPrint('Name: ${request.holidayName}');
      debugPrint('Description: ${request.description}');
      debugPrint('JSON: ${request.toJson()}');
      debugPrint('========================================');

      // =========================================================
      // 1. CREATE HOLIDAY
      // =========================================================

      final createdHoliday =
          await _holidayService.create(request);

      debugPrint(
        'HOLIDAY CREATED SUCCESSFULLY: '
        '${createdHoliday.id}',
      );

      if (!mounted) return false;

      // =========================================================
      // 2. IMPORTANT:
      //    POST WAS SUCCESSFUL.
      //    DO NOT LET A REFRESH ERROR MAKE SAVE LOOK LIKE FAILURE.
      // =========================================================

      _showSuccess(
        'Holiday created successfully.',
      );

      // Close dialog immediately because save succeeded.
      return true;
    } on AttendanceHolidayApiException catch (e) {
      debugPrint(
        '========================================',
      );
      debugPrint(
        'HOLIDAY API ERROR',
      );
      debugPrint(
        'Status: ${e.statusCode}',
      );
      debugPrint(
        'Message: ${e.message}',
      );
      debugPrint(
        '========================================',
      );

      if (!mounted) return false;

      _showError(
        e.message,
      );

      return false;
    } catch (e, stackTrace) {
      debugPrint(
        '========================================',
      );
      debugPrint(
        'HOLIDAY SAVE ERROR',
      );
      debugPrint(
        '$e',
      );
      debugPrint(
        stackTrace.toString(),
      );
      debugPrint(
        '========================================',
      );

      if (!mounted) return false;

      _showError(
        'Unable to save holiday.\n\n$e',
      );

      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // =========================================================
  // DELETE HOLIDAY
  // =========================================================

  // =========================================================
  // DELETE CONFIRMATION
  // =========================================================

  // =========================================================
  // ADD HOLIDAY DIALOG
  // =========================================================

  Future<void> _showAddHolidayDialog() async {
    final daysInMonth = DateUtils.getDaysInMonth(
      _selectedMonth.year,
      _selectedMonth.month,
    );

    final today = DateTime.now();

    DateTime selectedDate = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      today.day.clamp(1, daysInMonth),
    );

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    HolidayType selectedType =
        HolidayType.publicHoliday;

    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.event_available,
                    color: accentColor,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Add Holiday',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // =================================================
                        // DATE
                        // =================================================

                        InkWell(
                          borderRadius:
                              BorderRadius.circular(14),
                          onTap: () async {
                            final picked =
                                await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate:
                                  DateTime(2000),
                              lastDate:
                                  DateTime(2100),
                              builder:
                                  (context, child) {
                                return Theme(
                                  data: Theme.of(
                                    context,
                                  ).copyWith(
                                    colorScheme:
                                        const ColorScheme.dark(
                                      primary:
                                          accentColor,
                                      surface:
                                          cardColor,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );

                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius:
                                  BorderRadius.circular(
                                14,
                              ),
                              border: Border.all(
                                color: Colors.white12,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month,
                                  color: accentColor,
                                ),
                                const SizedBox(
                                  width: 12,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      const Text(
                                        'Holiday Date',
                                        style:
                                            TextStyle(
                                          color:
                                              textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 3,
                                      ),
                                      Text(
                                        _displayDate(
                                          selectedDate,
                                        ),
                                        style:
                                            const TextStyle(
                                          color:
                                              textPrimary,
                                          fontSize: 15,
                                          fontWeight:
                                              FontWeight
                                                  .w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  color: textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // =================================================
                        // HOLIDAY TYPE
                        // =================================================

                        DropdownButtonFormField<
                            HolidayType>(
                          value: selectedType,
                          dropdownColor: cardColor,
                          style: const TextStyle(
                            color: textPrimary,
                          ),
                          decoration: _inputDecoration(
                            label: 'Holiday Type',
                            icon: Icons.category,
                          ),
                          items: HolidayType.values
                              .map(
                                (type) =>
                                    DropdownMenuItem<
                                        HolidayType>(
                                  value: type,
                                  child: Text(
                                    type.displayName,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                selectedType = value;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 16),

                        // =================================================
                        // HOLIDAY NAME
                        // =================================================

                        TextFormField(
                          controller: nameController,
                          textCapitalization:
                              TextCapitalization.words,
                          style: const TextStyle(
                            color: textPrimary,
                          ),
                          decoration: _inputDecoration(
                            label: 'Holiday Name',
                            hint: 'Example: Diwali',
                            icon: Icons.celebration,
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Holiday name is required';
                            }

                            if (value.trim().length >
                                255) {
                              return 'Holiday name is too long';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // =================================================
                        // DESCRIPTION
                        // =================================================

                        TextFormField(
                          controller:
                              descriptionController,
                          maxLines: 3,
                          maxLength: 500,
                          textCapitalization:
                              TextCapitalization.sentences,
                          style: const TextStyle(
                            color: textPrimary,
                          ),
                          decoration: _inputDecoration(
                            label: 'Description',
                            hint:
                                'Optional description',
                            icon: Icons.description,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          Navigator.pop(
                            dialogContext,
                            false,
                          );
                        },
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(
                      color: textSecondary,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: backgroundColor,
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: backgroundColor,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isSaving
                        ? 'SAVING...'
                        : 'SAVE',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (!formKey
                              .currentState!
                              .validate()) {
                            return;
                          }

                          
                          final success = await _createHoliday(
                            date: selectedDate,
                            holidayType: selectedType,
                            holidayName: nameController.text.trim(),
                            description: descriptionController.text.trim(),
                          );

                          if (success &&
                              dialogContext
                                  .mounted) {
                            Navigator.pop(
                              dialogContext,
                              true,
                            );
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();

    if (created == true && mounted) {
      setState(() {});
    }
  }

  // =========================================================
  // MONTH PICKER
  // =========================================================

  Future<void> _selectMonth() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        int year = _selectedMonth.year;

        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Select Month',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {
                            setDialogState(() {
                              year--;
                            });
                          },
                          icon: const Icon(
                            Icons.chevron_left,
                            color: accentColor,
                          ),
                        ),
                        Text(
                          '$year',
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setDialogState(() {
                              year++;
                            });
                          },
                          icon: const Icon(
                            Icons.chevron_right,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      itemCount: 12,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.7,
                      ),
                      itemBuilder:
                          (context, index) {
                        final month = index + 1;

                        final selected =
                            month ==
                                    _selectedMonth
                                        .month &&
                                year ==
                                    _selectedMonth
                                        .year;

                        return InkWell(
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                          onTap: () {
                            Navigator.pop(
                              dialogContext,
                              DateTime(year, month),
                            );
                          },
                          child: Container(
                            alignment:
                                Alignment.center,
                            decoration:
                                BoxDecoration(
                              color: selected
                                  ? accentColor
                                  : backgroundColor,
                              borderRadius:
                                  BorderRadius.circular(
                                10,
                              ),
                            ),
                            child: Text(
                              _monthShortName(
                                month,
                              ),
                              style: TextStyle(
                                color: selected
                                    ? backgroundColor
                                    : textPrimary,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = picked;
      });

      await _loadHolidays();
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: accentColor,
          ),
          onPressed: () =>
              Navigator.of(context).pop(),
        ),
        title: const Text(
          'Public Holidays',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: accentColor,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _isLoading ? null : _loadHolidays,
            icon: const Icon(
              Icons.refresh,
              color: accentColor,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildMonthHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(
                        color: accentColor,
                      ),
                    )
                  : RefreshIndicator(
                      color: accentColor,
                      backgroundColor: cardColor,
                      onRefresh: _loadHolidays,
                      child: _holidays.isEmpty
                          ? _buildEmptyState()
                          : _buildHolidayList(),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        backgroundColor: accentColor,
        foregroundColor: backgroundColor,
        onPressed: _isSaving
            ? null
            : _showAddHolidayDialog,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Holiday',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // MONTH HEADER
  // =========================================================

  Widget _buildMonthHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        8,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF11998E),
            Color(0xFF38EF7D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_month,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Holiday Calendar',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_monthName(_selectedMonth.month)} '
                  '${_selectedMonth.year}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius:
                BorderRadius.circular(12),
            onTap: _selectMonth,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color:
                    Colors.white.withOpacity(0.18),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.tune,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Month',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // HOLIDAY LIST
  // =========================================================

  Widget _buildHolidayList() {
    return ListView.builder(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        100,
      ),
      itemCount: _holidays.length,
      itemBuilder: (context, index) {
        final holiday = _holidays[index];

        return _buildHolidayCard(holiday);
      },
    );
  }

  // =========================================================
  // HOLIDAY CARD
  // =========================================================

  Widget _buildHolidayCard(
    AttendanceHoliday holiday,
  ) {
    final isActive = holiday.active;

    return Container(
      margin:
          const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? Colors.white12
              : Colors.redAccent
                  .withOpacity(0.25),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            // =================================================
            // DATE
            // =================================================

            Container(
              width: 62,
              height: 70,
              decoration: BoxDecoration(
                color: isActive
                    ? accentColor
                        .withOpacity(0.12)
                    : Colors.redAccent
                        .withOpacity(0.10),
                borderRadius:
                    BorderRadius.circular(14),
                border: Border.all(
                  color: isActive
                      ? accentColor
                          .withOpacity(0.25)
                      : Colors.redAccent
                          .withOpacity(0.25),
                ),
              ),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(
                    '${holiday.holidayDate.day}',
                    style: TextStyle(
                      color: isActive
                          ? accentColor
                          : Colors.redAccent,
                      fontSize: 24,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  Text(
                    _monthShortName(
                      holiday.holidayDate.month,
                    ),
                    style: TextStyle(
                      color: isActive
                          ? textSecondary
                          : Colors.redAccent,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // =================================================
            // DETAILS
            // =================================================

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    holiday.holidayName,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    children: [
                      _buildTypeBadge(
                        holiday.holidayType,
                      ),
                      _buildStatusBadge(
                        isActive,
                      ),
                    ],
                  ),
                  if (holiday.description != null &&
                      holiday.description!
                          .trim()
                          .isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      holiday.description!,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // =================================================
            // DELETE
            // =================================================

            IconButton(
              tooltip: 'Remove Holiday',
              onPressed:(){},
              icon: Icon(
                Icons.delete_outline,
                color: _isDeleting
                    ? Colors.white24
                    : Colors.redAccent
                        .withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // TYPE BADGE
  // =========================================================

  Widget _buildTypeBadge(
    HolidayType type,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            Colors.white.withOpacity(0.07),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        type.displayName,
        style: const TextStyle(
          color: textSecondary,
          fontSize: 10,
          fontWeight:
              FontWeight.w600,
        ),
      ),
    );
  }

  // =========================================================
  // STATUS BADGE
  // =========================================================

  Widget _buildStatusBadge(
    bool active,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: active
            ? successColor.withOpacity(0.12)
            : dangerColor.withOpacity(0.12),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(
              color: active
                  ? successColor
                  : dangerColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            active
                ? 'ACTIVE'
                : 'INACTIVE',
            style: TextStyle(
              color: active
                  ? successColor
                  : dangerColor,
              fontSize: 9,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // EMPTY STATE
  // =========================================================

  Widget _buildEmptyState() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height:
              MediaQuery.of(context)
                  .size
                  .height *
              0.45,
          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.all(
                      22,
                    ),
                    decoration:
                        BoxDecoration(
                      color: accentColor
                          .withOpacity(0.08),
                      shape:
                          BoxShape.circle,
                    ),
                    child:
                        const Icon(
                      Icons.event_busy,
                      size: 55,
                      color:
                          accentColor,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  const Text(
                    'No Holidays',
                    style:
                        TextStyle(
                      color:
                          textPrimary,
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    'No holidays have been marked for '
                    '${_monthName(_selectedMonth.month)} '
                    '${_selectedMonth.year}.',
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      color:
                          textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  ElevatedButton
                      .icon(
                    style:
                        ElevatedButton
                            .styleFrom(
                      backgroundColor:
                          accentColor,
                      foregroundColor:
                          backgroundColor,
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onPressed:
                        _showAddHolidayDialog,
                    icon:
                        const Icon(
                      Icons.add,
                    ),
                    label:
                        const Text(
                      'Add Holiday',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // INPUT DECORATION
  // =========================================================

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle:
          const TextStyle(
        color: textSecondary,
      ),
      hintStyle:
          const TextStyle(
        color: Colors.white30,
      ),
      prefixIcon:
          Icon(
        icon,
        color: accentColor,
      ),
      filled: true,
      fillColor:
          backgroundColor,
      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        borderSide:
            BorderSide.none,
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        borderSide:
            const BorderSide(
          color: Colors.white12,
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        borderSide:
            const BorderSide(
          color: accentColor,
          width: 1.2,
        ),
      ),
      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        borderSide:
            const BorderSide(
          color: dangerColor,
        ),
      ),
      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        borderSide:
            const BorderSide(
          color: dangerColor,
          width: 1.2,
        ),
      ),
    );
  }

  // =========================================================
  // DATE HELPERS
  // =========================================================

  String _displayDate(
    DateTime date,
  ) {
    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year}';
  }

  String _monthName(
    int month,
  ) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }

  String _monthShortName(
    int month,
  ) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];

    return months[month - 1];
  }

  // =========================================================
  // SUCCESS SNACKBAR
  // =========================================================

  void _showSuccess(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              const Color(0xFF1E5C45),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: successColor,
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: Text(
                  message,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // =========================================================
  // ERROR SNACKBAR
  // =========================================================

  void _showError(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              const Color(0xFF632F35),
          duration:
              const Duration(
            seconds: 4,
          ),
          content: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color:
                    Colors.redAccent,
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: Text(
                  message,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}