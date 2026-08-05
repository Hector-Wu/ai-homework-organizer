// Filename: Sheets/PrivacyView.swift
// 用途：开源项目法律声明与隐私政策 (AGPL-3.0 专用版)

import SwiftUI

struct PrivacyView: View {
    @Binding var isPresented: Bool
    var language: AppLanguage
    
    var isEnglish: Bool { language == .english }
    
    // 辅助文本切换函数
    private func isEn(_ en: String, _ zh: String) -> String {
        return isEnglish ? en : zh
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEnglish ? "Legal Notice & Privacy Policy" : "法律声明与隐私政策")
                    .scaledFont(size: 16, weight: .bold)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray).font(.title2)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    // 重要提示
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isEn("IMPORTANT NOTICE", "重要提示"))
                            .scaledFont(size: 13, weight: .bold).foregroundColor(.red)
                        Text(isEn(
                            "THIS IS FREE AND OPEN SOURCE SOFTWARE. YOU ARE USING IT AT YOUR OWN RISK. THE DEVELOPER PROVIDES NO WARRANTIES OF ANY KIND.",
                            "这是免费开源软件。您需自行承担使用风险。开发者不提供任何形式的保证。"
                        ))
                        .scaledFont(size: 11).foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    
                    // 前言
                    Text(isEn(
                        "Last Updated: June 8, 2026\n\nThis document constitutes the legal agreement between you (the \"User\") and the original developer of Homework Assistant. By downloading, installing, or using the Software, you agree to be bound by all terms and conditions set forth in this document.",
                        "最后更新日期：2026年8月5日\n\n本文件构成您（\"用户\"）与作业助手原始开发者之间的法律协议。下载、安装或使用本软件，即表示您同意受本文件所有条款和条件的约束。"
                    ))
                    .scaledFont(size: 11.5).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    
                    // 1. 开源许可证条款
                    policyCard(
                        title: isEn("1. Open Source License (AGPL-3.0)", "1. 开源许可证（AGPL-3.0）"),
                        body: isEn(
                            "This Software is licensed under the GNU Affero General Public License v3.0 (\"AGPL-3.0\"). You are granted the right to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, subject to the following conditions:\n\n" +
                            "• You must include a copy of the AGPL-3.0 license in all copies or substantial portions of the Software.\n" +
                            "• If you modify the Software and make it available to others over a network, you must make your modified source code available to all users of that network service.\n" +
                            "• You may not use the name or trademarks of the original developer to endorse or promote products derived from the Software without specific prior written permission.\n\n" +
                            "Full license: https://www.gnu.org/licenses/agpl-3.0.html",
                            "本软件采用 GNU Affero General Public License v3.0（\"AGPL-3.0\"）许可证授权。您被授予使用、复制、修改、合并、发布、分发、再许可和/或销售本软件副本的权利，但须遵守以下条件：\n\n" +
                            "• 您必须在本软件的所有副本或重要部分中包含一份 AGPL-3.0 许可证副本。\n" +
                            "• 如果您修改本软件并通过网络向他人提供服务，您必须向该网络服务的所有用户提供您修改后的源代码。\n" +
                            "• 未经原始开发者事先书面许可，您不得使用原始开发者的名称或商标来宣传或推广源自本软件的产品。\n\n" +
                            "许可证全文：https://www.gnu.org/licenses/agpl-3.0.html"
                        )
                    )
                    
                    // 2. 零数据收集隐私政策
                    policyCard(
                        title: isEn("2. Privacy Policy: Zero Data Collection", "2. 隐私政策：零数据收集"),
                        body: isEn(
                            "The Software operates on a strict \"zero data collection\" principle. The original developer does NOT:\n\n" +
                            "• Collect, store, or transmit any personal information\n" +
                            "• Collect, store, or transmit any user-generated content\n" +
                            "• Collect any usage statistics or analytics data\n" +
                            "• Communicate with any servers operated by the original developer\n\n" +
                            "All data is stored exclusively on your local device using Apple's SwiftData framework. The original developer has no ability to access your data at any time.",
                            "本软件遵循严格的\"零数据收集\"原则。原始开发者不会：\n\n" +
                            "• 收集、存储或传输任何个人信息\n" +
                            "• 收集、存储或传输任何用户生成的内容\n" +
                            "• 收集任何使用统计数据或分析数据\n" +
                            "• 与任何原始开发者运营的服务器进行通信\n\n" +
                            "所有数据仅通过 Apple SwiftData 框架存储在您的本地设备上。原始开发者在任何时候都无法访问您的数据。"
                        )
                    )
                    
                    // 3. 第三方 AI 服务责任划分
                    policyCard(
                        title: isEn("3. Third-Party AI Services", "3. 第三方 AI 服务"),
                        body: isEn(
                            "The Software includes optional AI functionality that requires you to provide your own API keys (\"BYOK\" model). By using this functionality:\n\n" +
                            "• You are solely responsible for obtaining and managing your own API keys.\n" +
                            "• All data you input will be sent directly to the third-party AI provider you select (Groq or Zhipu AI).\n" +
                            "• You agree to comply with all terms of service and privacy policies of the third-party provider.\n" +
                            "• You are solely responsible for all costs incurred through your use of third-party AI services.\n" +
                            "• The original developer is not a party to any agreement between you and the third-party provider.",
                            "本软件包含可选的 AI 功能，该功能要求您提供自己的 API 密钥（\"BYOK\"模式）。使用该功能即表示您：\n\n" +
                            "• 确认您全权负责获取和管理自己的 API 密钥。\n" +
                            "• 确认您输入到 AI 功能中的所有数据将直接发送至您选择的第三方 AI 提供商。\n" +
                            "• 同意遵守第三方 AI 提供商的所有服务条款和隐私政策。\n" +
                            "• 全权负责因使用第三方 AI 服务而产生的所有费用和开支。\n" +
                            "• 原始开发者不是您与第三方 AI 提供商之间任何协议的一方。"
                        )
                    )
                    
                    // 4. 生成式 AI 全面免责声明
                    policyCard(
                        title: isEn("4. Generative AI Disclosure", "4. 生成式 AI 声明与免责"),
                        body: isEn(
                            "Portions of this Software's source code were written or assisted by generative artificial intelligence (\"AI\") models. Additionally, the Software provides functionality that uses AI models to process user input.\n\n" +
                            "You acknowledge and agree that:\n\n" +
                            "• AI models may produce incorrect, misleading, offensive, or harmful content.\n" +
                            "• AI-generated code may contain bugs, errors, vulnerabilities, or unintended behaviors.\n" +
                            "• The original developer has made reasonable efforts to test the Software, but cannot guarantee that all AI-generated content or code is free from errors.\n" +
                            "• You are solely responsible for verifying the accuracy and appropriateness of all AI-generated content.",
                            "本软件的部分源代码由生成式人工智能（\"AI\"）模型编写或辅助编写。此外，本软件提供使用 AI 模型处理用户输入的功能。\n\n" +
                            "您确认并同意：\n\n" +
                            "• AI 模型可能产生不正确、误导性、冒犯性或有害的内容。\n" +
                            "• AI 生成的代码可能包含错误、缺陷、漏洞或意外行为。\n" +
                            "• 原始开发者已尽合理努力测试本软件，但不能保证所有 AI 生成的内容或代码都没有错误。\n" +
                            "• 您全权负责验证所有 AI 生成内容的准确性和适当性。"
                        )
                    )
                    
                    // 5. 修改与分发责任
                    policyCard(
                        title: isEn("5. Modification and Distribution", "5. 修改与分发责任"),
                        body: isEn(
                            "If you modify or distribute copies of the Software, you do so at your own risk. The original developer is not responsible for any changes made by third parties to the Software.\n\n" +
                            "Any modified version must clearly state that it has been modified from the original version and must include a copy of this Legal Notice. You are solely responsible for any liabilities arising from your modification or distribution of the Software.",
                            "如果您修改或分发本软件的副本，您需自行承担由此产生的所有风险。原始开发者不对任何第三方对本软件所做的任何修改负责。\n\n" +
                            "任何修改后的版本必须明确说明其已从原始版本修改而来，并且必须包含本法律声明的副本。您全权负责因您修改或分发本软件而产生的任何法律责任。"
                        )
                    )
                    
                    // 6. 全面免责声明与责任限制
                    policyCard(
                        title: isEn("6. Comprehensive Disclaimer", "6. 全面免责声明"),
                        body: isEn(
                            "THE SOFTWARE IS PROVIDED \"AS IS\" AND \"AS AVAILABLE\" WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE, AND NON-INFRINGEMENT.\n\n" +
                            "IN NO EVENT SHALL THE ORIGINAL DEVELOPER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.\n\n" +
                            "This includes, without limitation, damages arising from:\n" +
                            "• Errors or omissions in the Software\n" +
                            "• Loss or corruption of data\n" +
                            "• Use of third-party AI services\n" +
                            "• Academic consequences resulting from use of the Software\n" +
                            "• Any modified version of the Software",
                            "本软件按\"现状\"和\"可用\"基础提供，不提供任何明示或暗示的保证，包括但不限于对适销性、特定用途适用性、所有权和非侵权性的保证。\n\n" +
                            "在任何情况下，原始开发者均不对任何直接、间接、附带、特殊、惩戒性或后果性损害（包括但不限于替代商品或服务的采购、使用、数据或利润的损失、或业务中断）承担责任，无论该责任是基于合同、严格责任还是侵权（包括疏忽或其他）理论，即使已被告知可能发生此类损害。\n\n" +
                            "这包括但不限于因以下原因引起的任何损害：\n" +
                            "• 本软件中的错误或遗漏\n" +
                            "• 数据丢失或损坏\n" +
                            "• 第三方 AI 服务的使用\n" +
                            "• 因使用本软件而导致的学术后果\n" +
                            "• 本软件的任何修改版本"
                        )
                    )
                    
                    // 7. 用户责任
                    policyCard(
                        title: isEn("7. User Responsibilities", "7. 用户责任"),
                        body: isEn(
                            "You agree to use the Software only for lawful purposes and in accordance with all applicable laws and regulations. You are solely responsible for:\n\n" +
                            "• All content that you input into the Software\n" +
                            "• The consequences of using the Software\n" +
                            "• Backing up your own data\n" +
                            "• Complying with all applicable laws and regulations",
                            "您同意仅将本软件用于合法目的，并遵守所有适用的法律法规。您全权负责：\n\n" +
                            "• 您输入到本软件中的所有内容\n" +
                            "• 使用本软件的后果\n" +
                            "• 备份您自己的数据\n" +
                            "• 遵守所有适用的法律法规"
                        )
                    )
                    
                    // 8. 条款变更与管辖法律
                    policyCard(
                        title: isEn("8. Changes & Governing Law", "8. 声明变更与管辖法律"),
                        body: isEn(
                            "The original developer reserves the right to modify this Legal Notice at any time. Any changes will be posted on the project's official code repository. Your continued use of the Software after any changes constitutes your acceptance of the modified terms.\n\n" +
                            "This agreement shall be governed by and construed in accordance with the laws of the People's Republic of China.",
                            "原始开发者保留随时修改本法律声明的权利。任何变更将在项目官方代码仓库中公布。您在变更后继续使用本软件即表示您接受修改后的条款。\n\n" +
                            "本协议受中华人民共和国法律管辖，并按其解释。"
                        )
                    )
                    
                    Spacer(minLength: 20)
                }
                .padding(24)
            }
        }
        .frame(width: 550, height: 650)
    }
    
    // MARK: - 抽取为独立的 Card UI 组件
    @ViewBuilder
    private func policyCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(body)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}
