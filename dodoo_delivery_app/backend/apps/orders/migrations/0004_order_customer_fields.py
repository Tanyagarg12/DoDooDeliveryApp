from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("orders", "0003_fareconfig"),
    ]

    operations = [
        migrations.AddField(
            model_name="order",
            name="customer_name",
            field=models.CharField(blank=True, default="", max_length=100),
        ),
        migrations.AddField(
            model_name="order",
            name="customer_phone",
            field=models.CharField(blank=True, default="", max_length=20),
        ),
    ]
