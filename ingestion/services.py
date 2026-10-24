import pandas as pd
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation


REQUIRED_COLUMNS = {
    "transaction_id",
    "sold_at",
    "sku",
    "quantity",
    "unit_price",
    "unit_cost",
}


@dataclass
class ValidationResult:
    rows_read: int
    valid_rows: list[dict]
    rejected_rows: list[dict]

    @property
    def rows_valid(self):
        return len(self.valid_rows)

    @property
    def rows_rejected(self):
        return len(self.rejected_rows)

    @property
    def errors(self):
        return [
            {
                "row": item["source_row_number"],
                "reason": item["reason"],
            }
            for item in self.rejected_rows[:200]
        ]


def validate_sales_csv(file_path) -> ValidationResult:
    df = pd.read_csv(
        file_path,
        dtype={
            "transaction_id": "string",
            "sku": "string",
        },
    )

    rows_read = len(df)
    missing = REQUIRED_COLUMNS - set(df.columns)

    if missing:
        raise ValueError(
            "Missing required columns: "
            + ", ".join(sorted(missing))
        )

    # The header is physical CSV line 1.
    df = df.reset_index(drop=True)
    valid_rows = []
    rejected_rows = []
    seen_keys = set()

    for index, row in df.iterrows():
        source_row_number = int(index) + 2

        raw_data = {
            str(key): (
                None if pd.isna(value) else str(value)
            )
            for key, value in row.to_dict().items()
        }

        transaction_id = (
            "" if pd.isna(row["transaction_id"])
            else str(row["transaction_id"]).strip()
        )
        sku = (
            "" if pd.isna(row["sku"])
            else str(row["sku"]).strip()
        )

        reasons = []

        if not transaction_id:
            reasons.append("Missing transaction_id")

        if not sku:
            reasons.append("Missing SKU")

        try:
            sold_at = pd.to_datetime(
                row["sold_at"],
                errors="raise",
                utc=True,
            ).to_pydatetime()
        except (ValueError, TypeError, OverflowError):
            sold_at = None
            reasons.append("Invalid sold_at date")

        try:
            quantity_decimal = Decimal(str(row["quantity"]))
            if (
                not quantity_decimal.is_finite()
                or quantity_decimal <= 0
                or quantity_decimal
                != quantity_decimal.to_integral_value()
            ):
                raise InvalidOperation
            quantity = int(quantity_decimal)
        except (InvalidOperation, ValueError, TypeError):
            quantity = None
            reasons.append(
                "Quantity must be a positive integer"
            )

        def parse_money(value, field_name):
            try:
                amount = Decimal(str(value))
                if not amount.is_finite() or amount < 0:
                    raise InvalidOperation

                if amount.as_tuple().exponent < -2:
                    raise InvalidOperation

                if amount > Decimal("9999999999.99"):
                    raise InvalidOperation

                return amount
            except (InvalidOperation, ValueError, TypeError):
                reasons.append(
                    f"{field_name} must be a non-negative "
                    "number with at most 2 decimal places"
                )
                return None

        unit_price = parse_money(
            row["unit_price"],
            "unit_price",
        )
        unit_cost = parse_money(
            row["unit_cost"],
            "unit_cost",
        )

        key = (transaction_id, sku)

        if transaction_id and sku:
            if key in seen_keys:
                reasons.append(
                    "Duplicate transaction_id and SKU in file"
                )
            else:
                seen_keys.add(key)

        if reasons:
            rejected_rows.append({
                "source_row_number": source_row_number,
                "raw_data": raw_data,
                "reason": "; ".join(reasons),
            })
            continue

        valid_rows.append({
            "transaction_id": transaction_id,
            "sold_at": sold_at,
            "sku": sku,
            "quantity": quantity,
            "unit_price": unit_price,
            "unit_cost": unit_cost,
            "source_row_number": source_row_number,
        })

    return ValidationResult(
        rows_read=rows_read,
        valid_rows=valid_rows,
        rejected_rows=rejected_rows,
    )
