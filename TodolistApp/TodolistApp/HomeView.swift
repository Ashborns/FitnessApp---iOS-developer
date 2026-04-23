//
//  HomeView.swift
//  TodolistApp
//

import SwiftUI

enum TodoFilter: String, CaseIterable { case all = "All", active = "Active", completed = "Done" }
enum TodoSort: String, CaseIterable { case createdAt = "Date", dueDate = "Due", priority = "Priority" }
enum TimePeriod: String, CaseIterable { case all = "All", daily = "Today", weekly = "Week", monthly = "Month" }

struct HomeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var todoVM: TodoViewModel
    @EnvironmentObject var theme: ThemeManager

    @State private var filter: TodoFilter = .all
    @State private var sortBy: TodoSort = .createdAt
    @State private var period: TimePeriod = .all
    @State private var showAddSheet = false
    @State private var editingTodo: TodoItem?
    @State private var animateHeader = false

    private var userId: String { authVM.userSession?.uid ?? "" }

    // MARK: - Filtering Logic

    /// Returns todos that belong to the selected time period.
    /// Rules:
    ///   • Recurring tasks always appear in their matching period
    ///     (daily → Today, weekly → Week/Today, monthly → Month/Week/Today)
    ///   • One-time tasks without a dueDate appear in ALL periods
    ///   • Overdue incomplete tasks always surface in every period
    private var periodTodos: [TodoItem] {
        switch period {
        case .all:
            return todoVM.todos

        case .daily:
            return todoVM.todos.filter { t in
                if t.recurrence == .daily { return true }
                guard let d = t.dueDate else { return t.recurrence == .oneTime }
                return d.isToday || (d.isOverdue && !t.isCompleted)
            }

        case .weekly:
            return todoVM.todos.filter { t in
                if t.recurrence == .daily || t.recurrence == .weekly { return true }
                guard let d = t.dueDate else { return t.recurrence == .oneTime }
                return d.isThisWeek || (d.isOverdue && !t.isCompleted)
            }

        case .monthly:
            return todoVM.todos.filter { t in
                if t.recurrence != .oneTime { return true }
                guard let d = t.dueDate else { return true }
                return d.isThisMonth || (d.isOverdue && !t.isCompleted)
            }
        }
    }

    private var displayed: [TodoItem] {
        let base: [TodoItem]
        switch filter {
        case .all:       base = periodTodos
        case .active:    base = periodTodos.filter { !$0.isCompleted }
        case .completed: base = periodTodos.filter { $0.isCompleted }
        }
        return base.sorted { a, b in
            switch sortBy {
            case .createdAt: return a.createdAt > b.createdAt
            case .dueDate:
                guard let da = a.dueDate else { return false }
                guard let db = b.dueDate else { return true }
                return da < db
            case .priority:
                let o: [Priority] = [.high, .medium, .low]
                return (o.firstIndex(of: a.priority) ?? 2) < (o.firstIndex(of: b.priority) ?? 2)
            }
        }
    }

    private var doneCount:  Int    { periodTodos.filter { $0.isCompleted }.count }
    private var totalCount: Int    { periodTodos.count }
    private var progress:   Double { totalCount == 0 ? 0 : Double(doneCount) / Double(totalCount) }

    // MARK: - Body

    var body: some View {
        TabView {
            todoTab.tabItem { Label("Tasks",   systemImage: "checklist") }
            ProfileView().tabItem { Label("Profile", systemImage: "person.circle.fill") }
        }
        .tint(theme.accent)
        .onAppear {
            todoVM.startListening(userId: userId)
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) { animateHeader = true }
        }
    }

    // MARK: - Todo Tab

    private var todoTab: some View {
        ZStack(alignment: .bottomTrailing) {
            AppBG()

            List {
                // ── Header ──────────────────────────────────────────────
                Section {
                    headerSection
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                // ── Summary Card ────────────────────────────────────────
                Section {
                    summaryCard
                        .listRowInsets(.init(top: 0, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                // ── Period + Filter ─────────────────────────────────────
                Section {
                    // Period Picker
                    periodPickerView
                        .listRowInsets(.init(top: 0, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .buttonStyle(.borderless)   // ← KEY FIX

                    // Filter pills + sort
                    filterRowView
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .buttonStyle(.borderless)   // ← KEY FIX
                }

                // ── Todo Items ──────────────────────────────────────────
                Section {
                    if todoVM.isLoading {
                        HStack { Spacer(); ProgressView().tint(theme.accentLight); Spacer() }
                            .padding(.vertical, 40)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                    } else if displayed.isEmpty {
                        emptyState
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                    } else {
                        ForEach(displayed) { todo in
                            TodoCard(
                                todo: todo,
                                onToggle: {
                                    withAnimation(.spring(response: 0.3)) {
                                        todoVM.toggleComplete(userId: userId, todo: todo)
                                    }
                                },
                                onEdit: { editingTodo = todo }
                            )
                            // ── Swipe right → Mark Done / Undo ──
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        todoVM.toggleComplete(userId: userId, todo: todo)
                                    }
                                } label: {
                                    Label(
                                        todo.isCompleted ? "Undo" : "Done",
                                        systemImage: todo.isCompleted
                                            ? "arrow.uturn.backward.circle.fill"
                                            : "checkmark.circle.fill"
                                    )
                                }
                                .tint(.successGreen)
                            }
                            // ── Swipe left → Edit / Delete ──────
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    guard let id = todo.id else { return }
                                    withAnimation { todoVM.deleteTodo(userId: userId, todoId: id) }
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }

                                Button { editingTodo = todo } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(theme.accent)
                            }
                            .listRowInsets(.init(top: 5, leading: 20, bottom: 5, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                }

                // Bottom spacer so FAB never covers last item
                Section {
                    Color.clear.frame(height: 80)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            // ── FAB ─────────────────────────────────────────────────────
            Button { showAddSheet = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(theme.gradient)
                    .clipShape(Circle())
                    .shadow(color: theme.accent.opacity(0.5), radius: 18, y: 8)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 90)
        }
        .sheet(isPresented: $showAddSheet) {
            AddTodoView(userId: userId)
                .environmentObject(todoVM)
                .environmentObject(theme)
        }
        .sheet(item: $editingTodo) { t in
            AddTodoView(userId: userId, editingTodo: t)
                .environmentObject(todoVM)
                .environmentObject(theme)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                Text(authVM.currentUser?.fullName.components(separatedBy: " ").first ?? "User")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(dayOfWeek).font(.caption2.weight(.semibold)).foregroundColor(theme.accentLight)
                Text(dayNum).font(.title2.weight(.bold)).foregroundColor(.white)
            }
            .frame(width: 52, height: 52)
            .glassCard(cornerRadius: 16)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .opacity(animateHeader ? 1 : 0)
        .offset(y: animateHeader ? 0 : 20)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.appCardHighlight, lineWidth: 6)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(theme.hGradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: progress)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(period == .all ? "Overall" : period.rawValue) Progress")
                    .font(.subheadline.weight(.semibold)).foregroundColor(.white)
                Text("\(doneCount) of \(totalCount) tasks done")
                    .font(.caption).foregroundColor(.textSecondary)
            }

            Spacer()

            VStack(spacing: 6) {
                miniStat(v: totalCount - doneCount, l: "Left", c: .priorityMedium)
                miniStat(v: doneCount, l: "Done", c: .successGreen)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 20)
    }

    private func miniStat(v: Int, l: String, c: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(c).frame(width: 7, height: 7)
            Text("\(v)").font(.caption.weight(.bold)).foregroundColor(.white)
            Text(l).font(.caption2).foregroundColor(.textSecondary)
        }
    }

    // MARK: - Period Picker
    // NOTE: Must use .buttonStyle(.borderless) at the call site (in List)

    private var periodPickerView: some View {
        HStack(spacing: 4) {
            ForEach(TimePeriod.allCases, id: \.self) { p in
                Button {
                    withAnimation(.spring(response: 0.3)) { period = p }
                } label: {
                    Text(p.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(period == p ? .white : .textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            period == p
                                ? AnyView(theme.hGradient)
                                : AnyView(Color.clear)
                        )
                        .cornerRadius(12)
                }
            }
        }
        .padding(4)
        .background(Color.appCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.glassStroke, lineWidth: 1))
    }

    // MARK: - Filter + Sort Row
    // NOTE: Must use .buttonStyle(.borderless) at the call site (in List)

    private var filterRowView: some View {
        HStack(spacing: 8) {
            // Filter pills — use a plain HStack instead of horizontal ScrollView
            // to avoid scroll conflict inside a List row
            HStack(spacing: 8) {
                ForEach(TodoFilter.allCases, id: \.self) { f in
                    Button {
                        withAnimation { filter = f }
                    } label: {
                        Text(f.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(filter == f ? .white : .textSecondary)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(filter == f ? theme.accent.opacity(0.3) : Color.appCard)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(filter == f
                                            ? theme.accent.opacity(0.5)
                                            : Color.glassStroke, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.leading, 20)

            Spacer()

            // Sort menu
            Menu {
                ForEach(TodoSort.allCases, id: \.self) { s in
                    Button { sortBy = s } label: {
                        Label(s.rawValue, systemImage: sortBy == s ? "checkmark" : "")
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .padding(9)
                    .background(Color.appCard)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.glassStroke, lineWidth: 1))
            }
            .padding(.trailing, 20)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 50)
            ZStack {
                Circle().fill(Color.appCardHighlight).frame(width: 90, height: 90)
                Image(systemName: filter == .completed ? "party.popper" : "tray")
                    .font(.system(size: 36)).foregroundColor(Color(hex: "3D3D5E"))
            }
            Text(filter == .completed ? "No completed tasks" : "No tasks here")
                .font(.headline).foregroundColor(.textSecondary)
            Text("Tap + to add a new task")
                .font(.subheadline).foregroundColor(Color(hex: "4D4D6E"))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "Good Morning,"
        case 12..<17: return "Good Afternoon,"
        case 17..<21: return "Good Evening,"
        default:      return "Good Night,"
        }
    }
    private var dayOfWeek: String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: Date())
    }
    private var dayNum: String {
        "\(Calendar.current.component(.day, from: Date()))"
    }
}
