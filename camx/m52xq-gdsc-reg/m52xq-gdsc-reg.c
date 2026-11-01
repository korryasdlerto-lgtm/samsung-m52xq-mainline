// SPDX-License-Identifier: GPL-2.0-only
/*
 * M52XQ: expose mainline camcc GDSC power domains as regulators.
 *
 * The stock (downstream) camera DT nodes and Qualcomm's camera-driver
 * (github.com/qualcomm-linux/camera-driver) take the camera GDSCs as
 * regulators ("camss-supply", "gdscr-supply", "ife0-supply",
 * "bps-vdd-supply", ...). Mainline models GDSCs as genpd power domains of
 * the camcc driver. Each DT node handled here carries one camcc power
 * domain; regulator enable/disable maps to pm_runtime get/put of that
 * domain. set_mode(FAST/NORMAL) (downstream: hand GDSC over to HW / back to
 * SW) is accepted as a no-op: mainline already runs the BPS/IPE GDSCs with
 * HW_CTRL.
 */
#include <linux/module.h>
#include <linux/of.h>
#include <linux/platform_device.h>
#include <linux/pm_runtime.h>
#include <linux/regulator/driver.h>
#include <linux/regulator/machine.h>
#include <linux/regulator/of_regulator.h>

struct m52xq_gdsc_reg {
	struct device *dev;
	struct regulator_desc desc;
	bool enabled;
	unsigned int mode;
};

static int m52xq_gdsc_enable(struct regulator_dev *rdev)
{
	struct m52xq_gdsc_reg *g = rdev_get_drvdata(rdev);
	int ret;

	ret = pm_runtime_resume_and_get(g->dev);
	if (ret) {
		dev_err(g->dev, "power domain on failed: %d\n", ret);
		return ret;
	}
	g->enabled = true;
	return 0;
}

static int m52xq_gdsc_disable(struct regulator_dev *rdev)
{
	struct m52xq_gdsc_reg *g = rdev_get_drvdata(rdev);

	g->enabled = false;
	pm_runtime_put_sync(g->dev);
	return 0;
}

static int m52xq_gdsc_is_enabled(struct regulator_dev *rdev)
{
	struct m52xq_gdsc_reg *g = rdev_get_drvdata(rdev);

	return g->enabled;
}

static int m52xq_gdsc_set_mode(struct regulator_dev *rdev, unsigned int mode)
{
	struct m52xq_gdsc_reg *g = rdev_get_drvdata(rdev);

	g->mode = mode;
	return 0;
}

static unsigned int m52xq_gdsc_get_mode(struct regulator_dev *rdev)
{
	struct m52xq_gdsc_reg *g = rdev_get_drvdata(rdev);

	return g->mode;
}

static const struct regulator_ops m52xq_gdsc_ops = {
	.enable = m52xq_gdsc_enable,
	.disable = m52xq_gdsc_disable,
	.is_enabled = m52xq_gdsc_is_enabled,
	.set_mode = m52xq_gdsc_set_mode,
	.get_mode = m52xq_gdsc_get_mode,
};

static int m52xq_gdsc_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct regulator_config cfg = { };
	struct regulator_init_data *init;
	struct regulator_dev *rdev;
	struct m52xq_gdsc_reg *g;
	int ret;

	if (!dev->pm_domain)
		return dev_err_probe(dev, -ENODEV, "no power domain attached\n");

	g = devm_kzalloc(dev, sizeof(*g), GFP_KERNEL);
	if (!g)
		return -ENOMEM;
	g->dev = dev;
	g->mode = REGULATOR_MODE_NORMAL;

	init = of_get_regulator_init_data(dev, dev->of_node, &g->desc);
	if (!init)
		return -ENOMEM;
	init->constraints.valid_ops_mask |= REGULATOR_CHANGE_STATUS |
					    REGULATOR_CHANGE_MODE;
	init->constraints.valid_modes_mask |= REGULATOR_MODE_NORMAL |
					      REGULATOR_MODE_FAST;
	/* parent-supply in the stock node is a downstream rail; not used */
	init->supply_regulator = NULL;

	g->desc.name = init->constraints.name ?: dev_name(dev);
	g->desc.type = REGULATOR_VOLTAGE;
	g->desc.owner = THIS_MODULE;
	g->desc.ops = &m52xq_gdsc_ops;

	ret = devm_pm_runtime_enable(dev);
	if (ret)
		return ret;

	cfg.dev = dev;
	cfg.init_data = init;
	cfg.driver_data = g;
	cfg.of_node = dev->of_node;

	rdev = devm_regulator_register(dev, &g->desc, &cfg);
	if (IS_ERR(rdev))
		return dev_err_probe(dev, PTR_ERR(rdev), "regulator register failed\n");

	dev_info(dev, "m52xq: %s -> camcc power domain\n", g->desc.name);
	return 0;
}

static const struct of_device_id m52xq_gdsc_of_match[] = {
	{ .compatible = "samsung,m52xq-gdsc-regulator" },
	{ }
};
MODULE_DEVICE_TABLE(of, m52xq_gdsc_of_match);

static struct platform_driver m52xq_gdsc_driver = {
	.probe = m52xq_gdsc_probe,
	.driver = {
		.name = "m52xq-gdsc-regulator",
		.of_match_table = m52xq_gdsc_of_match,
	},
};
module_platform_driver(m52xq_gdsc_driver);

MODULE_DESCRIPTION("M52XQ: camcc GDSC power domains as regulators for camera-driver");
MODULE_LICENSE("GPL");
