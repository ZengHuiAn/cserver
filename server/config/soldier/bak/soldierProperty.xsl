<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:template match="/">
		<html>
			<body>
				<h2>SoldierProperty</h2>
				<table border="1">
					<tr bgcolor="#9acd32">
						<td>类型</td>
						<td>等级</td>
						<td>名称</td>
						<td>攻击</td>
						<td>近防</td>
						<td>远防</td>
						<td>生命</td>
						<td>移动</td>
						<td>攻击距离</td>
						<td>速度</td>
						<td>命中</td>
						<td>闪避</td>
						<td>格挡</td>
						<td>暴击</td>
						<td>技能1</td>
						<td>技能2</td>
						<td>小图标</td>
						<td>大图标</td>
					</tr>
					<xsl:for-each select="Soldiers/Soldier">
					<tr>
						<td rowspan="11"><xsl:value-of select="@id"/></td>
					</tr>
					<xsl:for-each select="Level">
					<tr>
						<td><xsl:value-of select="@level"/></td>
						<td><xsl:value-of select="Name"/></td>
						<td><xsl:value-of select="Attack"/></td>
						<td><xsl:value-of select="MeleeDefense"/></td>
						<td><xsl:value-of select="RemoteDefense"/></td>
						<td><xsl:value-of select="Health"/></td>
						<td><xsl:value-of select="Move"/></td>
						<td><xsl:value-of select="Range"/></td>
						<td><xsl:value-of select="Speed"/></td>
						<td><xsl:value-of select="Hit"/></td>
						<td><xsl:value-of select="Dodge"/></td>
						<td><xsl:value-of select="Block"/></td>
						<td><xsl:value-of select="Crit"/></td>
						<td><xsl:value-of select="Skills/id[1]"/></td>
						<td><xsl:value-of select="Skills/id[2]"/></td>
						<td><xsl:value-of select="Images/Small"/></td>
						<td><xsl:value-of select="Images/Large"/></td>
					</tr>
					</xsl:for-each>
					</xsl:for-each>
				</table>
			</body>
		</html>
	</xsl:template>
</xsl:stylesheet>
