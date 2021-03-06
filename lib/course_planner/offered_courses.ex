defmodule CoursePlanner.OfferedCourses do
  @moduledoc false

  alias CoursePlanner.{OfferedCourse, Repo}
  import Ecto.Query

  def find_by_term_id(term_id) do
    term_id
    |> query_by_term_id()
    |> select([oc], {oc.id, oc})
    |> preload([:course, :students])
    |> Repo.all()
    |> Enum.into(%{})
  end

  def find_all_by_user(%{role: "Coordinator"}) do
    Repo.all(OfferedCourse)
  end
  def find_all_by_user(%{role: "Teacher", id: user_id}) do
    Repo.all(
      from oc in OfferedCourse,
      join: t in assoc(oc, :teachers),
      where: t.id == ^user_id
    )
  end
  def find_all_by_user(%{role: "Student", id: user_id}) do
    Repo.all(
      from oc in OfferedCourse,
      join: s in assoc(oc, :students),
      where: s.id == ^user_id
    )
  end

  def student_matrix(term_id) do
    offered_courses =
      term_id
      |> query_by_term_id()
      |> Repo.all()
      |> Repo.preload([:students])

    course_intersections =
      for oc1 <- offered_courses, oc2 <- offered_courses do
        student_ids1 = Enum.map(oc1.students, &(&1.id))
        student_ids2 = Enum.map(oc2.students, &(&1.id))
        {oc1.id, oc2.id, count_intersection(student_ids1, student_ids2)}
      end

    Enum.group_by(
      course_intersections,
      fn {oc1, _, _} -> oc1 end,
      fn {_, oc2, students} -> {oc2, students} end)
  end

  def query_by_term_id(term_id) do
    from oc in OfferedCourse, where: oc.term_id == ^term_id
  end

  def count_intersection(students1, students2) do
    Enum.count(students1, &(&1 in students2))
  end

  def get_subscribed_users(offered_courses) do
    offered_courses
    |> Enum.flat_map(fn(offered_course) ->
      Map.get(offered_course, :teachers) ++ Map.get(offered_course, :students)
    end)
    |> Enum.uniq_by(fn %{id: id} -> id end)
  end

  def with_pending_attendances(date \\ Timex.now()) do
   Repo.all(from oc in CoursePlanner.OfferedCourse,
     join: c in assoc(oc,  :classes),
     join: a in assoc(c,  :attendances),
     preload: [:teachers, :course, :term, classes: {c, attendances: a}],
     where: c.date < ^date and a.attendance_type == "Not filled")
  end
end
