defmodule Verify do
  @moduledoc """
  Rule engine: evaluates events against a list of rules using pattern matching.
  Returns a list of results per event (or per rule). No if/else chains.
  """

  def run(events, rules) when is_list(events) and is_list(rules) do
    Enum.map(events, fn event -> run_rules(event, rules) end)
  end

  def run(events, rules) when is_list(events), do: run(events, [rules])
  def run(event, rules) when is_map(event), do: run([event], rules)

  defp run_rules(event, rules) do
    results =
      Enum.map(rules, fn rule -> evaluate(event, rule) end)

    %{
      event: event,
      passed: Enum.all?(results, &match?({:pass, _}, &1)),
      results: results
    }
  end

  def evaluate(event, {:valid_pic, _opts}), do: evaluate_valid_pic(event)
  def evaluate(event, :valid_pic), do: evaluate_valid_pic(event)
  def evaluate(event, {:date_in_range, from: from, to: to}), do: evaluate_date_range(event, from, to)
  def evaluate(event, {:date_after, date}), do: evaluate_date_after(event, date)
  def evaluate(event, {:date_before, date}), do: evaluate_date_before(event, date)
  def evaluate(event, {:type_allowed, allowed}), do: evaluate_type_allowed(event, allowed)
  def evaluate(event, rule) when is_function(rule, 1), do: rule.(event)
  def evaluate(_, unknown), do: {:fail, {:unknown_rule, unknown}}

  defp evaluate_valid_pic(%{pic: pic}) do
    case PicValidator.validate(pic) do
      {:ok, _} -> {:pass, :valid_pic}
      {:error, reason} -> {:fail, {:invalid_pic, reason}}
    end
  end

  defp evaluate_valid_pic(_), do: {:fail, :missing_pic}

  defp evaluate_date_range(%{date: event_date}, from, to)
       when is_struct(event_date, Date) and is_struct(from, Date) and is_struct(to, Date) do
    case {Date.compare(event_date, from), Date.compare(event_date, to)} do
      {:lt, _} -> {:fail, {:date_before_range, event_date}}
      {_, :gt} -> {:fail, {:date_after_range, event_date}}
      _ -> {:pass, :date_in_range}
    end
  end

  defp evaluate_date_after(%{date: event_date}, after_date)
       when is_struct(event_date, Date) and is_struct(after_date, Date) do
    case Date.compare(event_date, after_date) do
      :lt -> {:fail, {:date_before_min, event_date}}
      _ -> {:pass, :date_after}
    end
  end

  defp evaluate_date_before(%{date: event_date}, before_date)
       when is_struct(event_date, Date) and is_struct(before_date, Date) do
    case Date.compare(event_date, before_date) do
      :gt -> {:fail, {:date_after_max, event_date}}
      _ -> {:pass, :date_before}
    end
  end

  defp evaluate_type_allowed(%{type: type}, allowed) when is_list(allowed) do
    case type in allowed do
      true -> {:pass, :type_allowed}
      false -> {:fail, {:type_not_allowed, type}}
    end
  end

  defp evaluate_type_allowed(%{type: type}, allowed) when is_atom(allowed) do
    evaluate_type_allowed(%{type: type}, [allowed])
  end
end
